import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/api/api_client.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/auth/auth_api.dart';
import 'package:mapmarker_app/data/auth/auth_session.dart';
import 'package:mapmarker_app/data/auth/auth_tokens.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_http.dart';

Matcher _failsWith(ApiFailure failure) =>
    throwsA(isA<ApiException>().having((e) => e.failure, 'failure', failure));

void main() {
  const first = AuthTokens(accessToken: 'a1', refreshToken: 'r1');

  late MemoryTokenStore store;
  late FakeHttp api;
  late FakeHttp auth;
  late AuthSession session;
  late ApiClient client;

  /// 'a2'만 받는 서버. 그 밖의 토큰은 401이다.
  FutureOr<FakeReply> acceptA2(RequestOptions request) =>
      request.headers['Authorization'] == 'Bearer a2'
      ? FakeReply.json(200, {'ok': true})
      : FakeReply.json(401);

  setUp(() {
    store = MemoryTokenStore(first);
    api = FakeHttp(acceptA2);
    auth = FakeHttp((_) => FakeReply.json(200, tokenJson('a2', 'r2')));
    session = AuthSession(
      store: store,
      api: AuthApi(fakeDio(auth)),
      tokens: first,
    );
    client = ApiClient(fakeDio(api), session);
    addTearDown(session.dispose);
  });

  group('createDio', () {
    test('주소 뒤에 /v1을 붙인다', () {
      expect(
        createDio('http://192.0.2.1:3000').options.baseUrl,
        'http://192.0.2.1:3000/v1',
      );
    });

    test('주소 끝의 /는 무시한다', () {
      expect(
        createDio('http://192.0.2.1:3000/').options.baseUrl,
        'http://192.0.2.1:3000/v1',
      );
    });

    test('응답이 없을 때 끝없이 기다리지 않는다', () {
      final options = createDio('http://192.0.2.1:3000').options;

      expect(options.connectTimeout, isNotNull);
      expect(options.sendTimeout, isNotNull);
      expect(options.receiveTimeout, isNotNull);
    });
  });

  group('요청', () {
    setUp(() => api.handler = (_) => FakeReply.json(200, {'ok': true}));

    test('access 토큰을 붙이고 응답 JSON을 돌려준다', () async {
      final result = await client.get('/trips');

      expect(api.requests.single.uri.toString(), 'http://test/v1/trips');
      expect(api.requests.single.headers['Authorization'], 'Bearer a1');
      expect(result, {'ok': true});
    });

    test('메서드와 본문을 그대로 보낸다', () async {
      await client.post('/a', data: {'x': 1});
      await client.patch('/b', data: {'x': 2});
      await client.put('/c', data: {'x': 3});
      await client.delete('/d');

      expect(
        [for (final r in api.requests) '${r.method} ${r.uri.path} ${r.data}'],
        [
          'POST /v1/a {x: 1}',
          'PATCH /v1/b {x: 2}',
          'PUT /v1/c {x: 3}',
          'DELETE /v1/d null',
        ],
      );
    });

    test('실패는 ApiException으로 나온다', () async {
      api.handler = (_) => FakeReply.json(409);

      await expectLater(client.post('/a'), _failsWith(ApiFailure.conflict));
      expect(auth.requests, isEmpty);
    });

    test('네트워크 실패는 network로 나온다', () async {
      api.handler = (request) => throw connectionError(request);

      await expectLater(client.get('/a'), _failsWith(ApiFailure.network));
    });

    test('로그아웃 상태면 보내지 않고 unauthorized다', () async {
      await session.logOut();
      auth.requests.clear();

      await expectLater(client.get('/a'), _failsWith(ApiFailure.unauthorized));
      expect(api.requests, isEmpty);
      expect(auth.requests, isEmpty);
    });
  });

  group('401이면', () {
    test('재발급해서 새 토큰으로 같은 요청을 다시 보낸다', () async {
      final result = await client.post('/trips', data: {'id': 'x'});

      expect(result, {'ok': true});
      expect(auth.requestsTo('/auth/refresh'), hasLength(1));
      expect(api.requests, hasLength(2));
      expect(api.requests.last.headers['Authorization'], 'Bearer a2');
      expect(api.requests.last.data, {'id': 'x'});
    });

    test('받은 토큰을 저장한 뒤에 다시 보낸다', () async {
      AuthTokens? savedAtLastCall;
      api.handler = (request) {
        savedAtLastCall = store.tokens;
        return acceptA2(request);
      };

      await client.get('/trips');

      expect(savedAtLastCall?.refreshToken, 'r2');
    });

    test('동시에 받은 401 여러 개는 재발급 하나를 함께 기다린다', () async {
      final reply = Completer<FakeReply>();
      auth.handler = (_) => reply.future;

      final calls = [client.get('/a'), client.get('/b'), client.get('/c')];
      await pumpEventQueue();
      reply.complete(FakeReply.json(200, tokenJson('a2', 'r2')));
      final results = await Future.wait(calls);

      expect(auth.requestsTo('/auth/refresh'), hasLength(1));
      expect(results, everyElement({'ok': true}));
    });

    test('재발급이 먼저 끝났으면 또 재발급하지 않고 다시 보낸다', () async {
      // 첫 요청의 401이 재발급이 끝난 뒤에 도착한다.
      final slow = Completer<FakeReply>();
      api.handler = (request) {
        final isSlow = request.uri.path.endsWith('/slow');
        if (isSlow && request.headers['Authorization'] == 'Bearer a1') {
          return slow.future;
        }
        return acceptA2(request);
      };

      final slowCall = client.get('/slow');
      await pumpEventQueue();
      await client.get('/fast');
      slow.complete(FakeReply.json(401));
      final result = await slowCall;

      expect(result, {'ok': true});
      expect(auth.requestsTo('/auth/refresh'), hasLength(1));
    });

    test('재발급 중에 시작한 요청은 새 토큰을 기다렸다가 보낸다', () async {
      final reply = Completer<FakeReply>();
      auth.handler = (_) => reply.future;

      final refreshing = session.refreshTokens();
      final call = client.get('/a');
      await pumpEventQueue();
      expect(api.requests, isEmpty);

      reply.complete(FakeReply.json(200, tokenJson('a2', 'r2')));
      await refreshing;
      await call;

      expect(api.requests.single.headers['Authorization'], 'Bearer a2');
    });

    test('재발급이 네트워크로 실패하면 그 실패로 끝나고 토큰은 남는다', () async {
      auth.handler = (request) => throw connectionError(request);

      await expectLater(client.get('/a'), _failsWith(ApiFailure.network));

      expect(session.isLoggedIn, isTrue);
      expect(store.tokens?.refreshToken, 'r1');
      expect(api.requests, hasLength(1));
    });

    test('재발급이 503이면 그 실패로 끝나고 토큰은 남는다', () async {
      auth.handler = (_) => FakeReply.json(503);

      await expectLater(client.get('/a'), _failsWith(ApiFailure.unavailable));

      expect(session.isLoggedIn, isTrue);
      expect(store.tokens?.refreshToken, 'r1');
    });

    test('재발급도 401이면 로그아웃하고 unauthorized로 끝난다', () async {
      auth.handler = (_) => FakeReply.json(401);

      await expectLater(client.get('/a'), _failsWith(ApiFailure.unauthorized));

      expect(session.isLoggedIn, isFalse);
      expect(store.tokens, isNull);
    });

    test('새 토큰으로도 401이면 더 돌지 않고 로그아웃하지 않는다', () async {
      api.handler = (_) => FakeReply.json(401);

      await expectLater(client.get('/a'), _failsWith(ApiFailure.unauthorized));

      expect(api.requests, hasLength(2));
      expect(auth.requestsTo('/auth/refresh'), hasLength(1));
      expect(session.isLoggedIn, isTrue);
    });

    test('로그아웃한 뒤 늦게 온 401은 재발급하지 않는다', () async {
      final slow = Completer<FakeReply>();
      api.handler = (_) => slow.future;

      final call = client.get('/a');
      await pumpEventQueue();
      await session.logOut();
      auth.requests.clear();
      slow.complete(FakeReply.json(401));

      await expectLater(call, _failsWith(ApiFailure.unauthorized));
      expect(auth.requests, isEmpty);
    });

    test('다른 계정으로 로그인한 뒤 늦게 온 401은 그 계정 토큰으로 다시 보내지 않는다', () async {
      final slow = Completer<FakeReply>();
      api.handler = (_) => slow.future;

      final call = client.get('/a');
      await pumpEventQueue();
      await session.logOut();
      await session.signIn(
        const AuthTokens(accessToken: 'other', refreshToken: 'other-r'),
      );
      auth.requests.clear();
      slow.complete(FakeReply.json(401));

      await expectLater(call, _failsWith(ApiFailure.unauthorized));
      expect(api.requests, hasLength(1));
      expect(auth.requests, isEmpty);
      expect(session.accessToken, 'other');
    });
  });
}

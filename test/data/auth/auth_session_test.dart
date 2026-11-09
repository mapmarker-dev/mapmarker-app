import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/auth/auth_api.dart';
import 'package:mapmarker_app/data/auth/auth_session.dart';
import 'package:mapmarker_app/data/auth/auth_tokens.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_http.dart';

Matcher _failsWith(ApiFailure failure) => throwsA(
  isA<ApiException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  const first = AuthTokens(accessToken: 'a1', refreshToken: 'r1');

  late MemoryTokenStore store;
  late FakeHttp http;

  AuthSession session([AuthTokens? tokens = first]) {
    store.tokens = tokens;
    final created = AuthSession(
      store: store,
      api: AuthApi(fakeDio(http)),
      tokens: tokens,
    );
    addTearDown(created.dispose);
    return created;
  }

  setUp(() {
    store = MemoryTokenStore();
    http = FakeHttp((_) => FakeReply.json(200, tokenJson('a2', 'r2')));
  });

  group('시작', () {
    test('기기에 토큰이 있으면 서버에 묻지 않고 로그인 상태다', () async {
      store.tokens = first;

      final restored = await AuthSession.restore(
        store: store,
        api: AuthApi(fakeDio(http)),
      );
      addTearDown(restored.dispose);

      expect(restored.isLoggedIn, isTrue);
      expect(restored.accessToken, 'a1');
      expect(http.requests, isEmpty);
    });

    test('기기에 토큰이 없으면 로그아웃 상태다', () async {
      final restored = await AuthSession.restore(
        store: store,
        api: AuthApi(fakeDio(http)),
      );
      addTearDown(restored.dispose);

      expect(restored.isLoggedIn, isFalse);
      expect(restored.accessToken, isNull);
    });
  });

  group('로그인', () {
    test('토큰을 저장하고 알린다', () async {
      final target = session(null);
      var notified = 0;
      target.addListener(() => notified++);

      await target.signIn(first);

      expect(target.isLoggedIn, isTrue);
      expect(store.tokens?.refreshToken, 'r1');
      expect(notified, 1);
    });

    test('저장에 실패해도 이번 실행 동안은 로그인 상태다', () async {
      final target = session(null);
      store.failWrites = true;

      await target.signIn(first);

      expect(target.accessToken, 'a1');
    });
  });

  group('재발급', () {
    test('받은 두 토큰을 저장한다', () async {
      final target = session();

      await target.refreshTokens();

      expect(target.accessToken, 'a2');
      expect(store.tokens?.accessToken, 'a2');
      expect(store.tokens?.refreshToken, 'r2');
      expect(http.requests.single.data, {'refreshToken': 'r1'});
    });

    test('동시에 불러도 서버에는 한 번만 보낸다', () async {
      final reply = Completer<FakeReply>();
      http.handler = (_) => reply.future;
      final target = session();

      final calls = [
        target.refreshTokens(),
        target.refreshTokens(),
        target.refreshTokens(),
      ];
      await pumpEventQueue();
      reply.complete(FakeReply.json(200, tokenJson('a2', 'r2')));
      await Future.wait(calls);

      expect(http.requests, hasLength(1));
    });

    test('끝난 뒤에 다시 부르면 새 토큰으로 다시 보낸다', () async {
      final target = session();

      await target.refreshTokens();
      await target.refreshTokens();

      expect(http.requests, hasLength(2));
      expect(http.requests.last.data, {'refreshToken': 'r2'});
    });

    Future<void> expectKept(
      FutureOr<FakeReply> Function(RequestOptions) handler,
      ApiFailure failure,
    ) async {
      http.handler = handler;
      final target = session();
      var notified = 0;
      target.addListener(() => notified++);

      await expectLater(target.refreshTokens(), _failsWith(failure));

      expect(target.isLoggedIn, isTrue);
      expect(target.accessToken, 'a1');
      expect(store.tokens?.refreshToken, 'r1');
      expect(notified, 0);
    }

    test('네트워크 실패로는 토큰을 지우지 않는다', () async {
      await expectKept(
        (request) => throw connectionError(request),
        ApiFailure.network,
      );
    });

    test('503으로는 토큰을 지우지 않는다', () async {
      await expectKept((_) => FakeReply.json(503), ApiFailure.unavailable);
    });

    test('500으로는 토큰을 지우지 않는다', () async {
      await expectKept((_) => FakeReply.json(500), ApiFailure.server);
    });

    test('200인데 토큰이 없어도 토큰을 지우지 않는다', () async {
      await expectKept(
        (_) => const FakeReply.raw(200, '<html></html>'),
        ApiFailure.server,
      );
    });

    test('재발급의 401이면 로그아웃하고 알린다', () async {
      http.handler = (_) => FakeReply.json(401);
      final target = session();
      var notified = 0;
      target.addListener(() => notified++);

      await expectLater(
        target.refreshTokens(),
        _failsWith(ApiFailure.unauthorized),
      );

      expect(target.isLoggedIn, isFalse);
      expect(store.tokens, isNull);
      expect(notified, 1);
    });

    test('실패한 뒤에는 다시 시도할 수 있다', () async {
      http.handler = (request) => throw connectionError(request);
      final target = session();
      await expectLater(target.refreshTokens(), throwsA(isA<ApiException>()));

      http.handler = (_) => FakeReply.json(200, tokenJson('a2', 'r2'));
      await target.refreshTokens();

      expect(target.accessToken, 'a2');
    });

    test('받은 토큰을 저장하지 못해도 새 토큰을 버리지 않는다', () async {
      // 예전 refresh 토큰은 이미 무효다. 버리면 다음 재발급이 재사용으로 걸려 로그아웃된다.
      final target = session();
      store.failWrites = true;

      await target.refreshTokens();

      expect(target.accessToken, 'a2');
      expect(target.isLoggedIn, isTrue);
    });

    test('로그인 상태가 아니면 보내지 않고 unauthorized다', () async {
      final target = session(null);

      await expectLater(
        target.refreshTokens(),
        _failsWith(ApiFailure.unauthorized),
      );
      expect(http.requests, isEmpty);
    });
  });

  group('로그아웃', () {
    test('기기 토큰을 지운 뒤 서버에 refresh 토큰을 보내고 알린다', () async {
      AuthTokens? savedAtServerCall = first;
      http.handler = (_) {
        savedAtServerCall = store.tokens;
        return FakeReply.json(204);
      };
      final target = session();
      var notified = 0;
      target.addListener(() => notified++);

      await target.logOut();

      expect(target.isLoggedIn, isFalse);
      expect(store.tokens, isNull);
      expect(savedAtServerCall, isNull);
      expect(notified, 1);
      expect(http.requestsTo('/auth/logout').single.data, {
        'refreshToken': 'r1',
      });
    });

    test('서버 로그아웃이 실패해도 로그아웃된다', () async {
      http.handler = (request) => throw connectionError(request);
      final target = session();

      await target.logOut();

      expect(target.isLoggedIn, isFalse);
      expect(store.tokens, isNull);
    });

    test('기기 토큰을 지우지 못해도 로그아웃된다', () async {
      final target = session();
      store.failClears = true;

      await target.logOut();

      expect(target.isLoggedIn, isFalse);
      expect(http.requestsTo('/auth/logout'), hasLength(1));
    });

    test('진행 중인 재발급을 기다렸다가 새 refresh 토큰으로 로그아웃한다', () async {
      final reply = Completer<FakeReply>();
      http.handler = (request) => request.uri.path.endsWith('/auth/refresh')
          ? reply.future
          : FakeReply.json(204);
      final target = session();

      final refreshing = target.refreshTokens();
      final loggingOut = target.logOut();
      await pumpEventQueue();
      expect(target.isLoggedIn, isTrue);
      expect(http.requestsTo('/auth/logout'), isEmpty);

      reply.complete(FakeReply.json(200, tokenJson('a2', 'r2')));
      await refreshing;
      await loggingOut;

      expect(target.isLoggedIn, isFalse);
      expect(store.tokens, isNull);
      expect(http.requestsTo('/auth/logout').single.data, {
        'refreshToken': 'r2',
      });
    });

    test('재발급이 실패해도 그 뒤 로그아웃은 끝난다', () async {
      final reply = Completer<FakeReply>();
      http.handler = (request) => request.uri.path.endsWith('/auth/refresh')
          ? reply.future
          : FakeReply.json(204);
      final target = session();

      final refreshing = target.refreshTokens();
      final loggingOut = target.logOut();
      reply.complete(FakeReply.json(503));
      await expectLater(refreshing, throwsA(isA<ApiException>()));
      await loggingOut;

      expect(target.isLoggedIn, isFalse);
      expect(http.requestsTo('/auth/logout').single.data, {
        'refreshToken': 'r1',
      });
    });

    test('로그아웃 상태면 서버에 보내지 않는다', () async {
      final target = session(null);

      await target.logOut();

      expect(http.requests, isEmpty);
    });

    test('로그인·로그아웃마다 세대가 바뀐다', () async {
      final target = session();
      final before = target.generation;

      await target.logOut();
      final loggedOut = target.generation;
      await target.signIn(first);

      expect(loggedOut, isNot(before));
      expect(target.generation, isNot(loggedOut));
    });
  });
}

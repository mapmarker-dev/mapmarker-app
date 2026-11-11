import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/auth/auth_api.dart';

import '../../helpers/fake_http.dart';

Matcher _failsWith(ApiFailure failure) =>
    throwsA(isA<ApiException>().having((e) => e.failure, 'failure', failure));

void main() {
  test('재발급은 refresh 토큰을 보내고 두 토큰을 받는다', () async {
    final http = FakeHttp((_) => FakeReply.json(200, tokenJson('a2', 'r2')));

    final tokens = await AuthApi(fakeDio(http)).refresh('r1');

    final request = http.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.toString(), 'http://test/v1/auth/refresh');
    expect(request.data, {'refreshToken': 'r1'});
    expect(request.headers['Authorization'], isNull);
    expect(tokens.accessToken, 'a2');
    expect(tokens.refreshToken, 'r2');
  });

  test('재발급 401은 unauthorized다', () async {
    final http = FakeHttp((_) => FakeReply.json(401));

    await expectLater(
      AuthApi(fakeDio(http)).refresh('r1'),
      _failsWith(ApiFailure.unauthorized),
    );
  });

  test('네트워크 실패는 network다', () async {
    final http = FakeHttp((request) => throw connectionError(request));

    await expectLater(
      AuthApi(fakeDio(http)).refresh('r1'),
      _failsWith(ApiFailure.network),
    );
  });

  test('공용 Wi-Fi 안내 페이지처럼 200인데 토큰이 없으면 server 실패다', () async {
    final http = FakeHttp((_) => const FakeReply.raw(200, '<html></html>'));

    await expectLater(
      AuthApi(fakeDio(http)).refresh('r1'),
      _failsWith(ApiFailure.server),
    );
  });

  test('로그아웃은 refresh 토큰을 보낸다', () async {
    final http = FakeHttp((_) => FakeReply.json(204));

    await AuthApi(fakeDio(http)).logout('r1');

    final request = http.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.toString(), 'http://test/v1/auth/logout');
    expect(request.data, {'refreshToken': 'r1'});
  });
}

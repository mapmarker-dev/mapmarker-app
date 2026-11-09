import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/auth/auth_tokens.dart';

import '../../helpers/fake_http.dart';

void main() {
  test('서버 응답에서 두 토큰을 꺼낸다', () {
    final tokens = AuthTokens.tryFromJson(tokenJson('a', 'r'));

    expect(tokens?.accessToken, 'a');
    expect(tokens?.refreshToken, 'r');
  });

  test('저장한 JSON을 다시 읽을 수 있다', () {
    final tokens = AuthTokens.tryFromJson(
      const AuthTokens(accessToken: 'a', refreshToken: 'r').toJson(),
    );

    expect(tokens?.accessToken, 'a');
    expect(tokens?.refreshToken, 'r');
  });

  test('토큰 모양이 아니면 null이다', () {
    for (final value in <Object?>[
      null,
      '<html>Wi-Fi 로그인</html>',
      <String, Object?>{},
      {'accessToken': 'a'},
      {'accessToken': 1, 'refreshToken': 'r'},
      {'accessToken': '', 'refreshToken': 'r'},
      {'accessToken': 'a', 'refreshToken': ''},
    ]) {
      expect(AuthTokens.tryFromJson(value), isNull, reason: '$value');
    }
  });

  test('글자로 바꿔도 토큰 값이 나오지 않는다', () {
    const tokens = AuthTokens(accessToken: 'SECRET-A', refreshToken: 'SECRET-R');

    expect(tokens.toString(), isNot(contains('SECRET')));
  });
}

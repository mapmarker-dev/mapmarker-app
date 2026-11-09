/// 서버가 준 토큰 두 개. refresh 토큰이 있으면 로그인 상태로 본다.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  /// 서버 응답이나 기기에 저장한 값을 읽는다. 토큰 모양이 아니면 null이다.
  static AuthTokens? tryFromJson(Object? json) => switch (json) {
    {'accessToken': final String access, 'refreshToken': final String refresh}
        when access.isNotEmpty && refresh.isNotEmpty =>
      AuthTokens(accessToken: access, refreshToken: refresh),
    _ => null,
  };

  Map<String, String> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}

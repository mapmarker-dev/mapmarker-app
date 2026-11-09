/// `--dart-define-from-file=.env`
abstract final class Env {
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

  /// 서버 주소.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}

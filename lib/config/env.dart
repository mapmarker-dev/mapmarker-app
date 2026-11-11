/// `--dart-define-from-file=.env`
abstract final class Env {
  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

  /// 서버 주소.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// 카카오 네이티브 앱 키.
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );

  /// 비어 있는 필수 값의 이름. 하나라도 있으면 앱 대신 안내 화면을 띄운다.
  static List<String> get missing => [
    if (naverMapClientId.isEmpty) 'NAVER_MAP_CLIENT_ID',
    if (apiBaseUrl.isEmpty) 'API_BASE_URL',
    if (kakaoNativeAppKey.isEmpty) 'KAKAO_NATIVE_APP_KEY',
  ];
}

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    show KakaoSdk;

import 'app/app.dart';
import 'config/env.dart';
import 'data/api/api_client.dart';
import 'data/auth/auth_api.dart';
import 'data/auth/auth_session.dart';
import 'data/auth/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  // Android 10에서는 시스템 사진 선택기를 쓴다.
  final imagePicker = ImagePickerPlatform.instance;
  if (imagePicker is ImagePickerAndroid) {
    imagePicker.useAndroidPhotoPicker = true;
  }
  if (Env.naverMapClientId.isNotEmpty) {
    await FlutterNaverMap().init(
      clientId: Env.naverMapClientId,
      onAuthFailed: (ex) => log('네이버 지도 인증 실패: $ex'),
    );
  }
  // 값이 비어 있으면 서버·로그인 준비 없이 안내 화면(MissingEnvScreen)만 띄운다.
  // 서버 주소가 비면 dio를 만들 수 없다.
  if (Env.missing.isNotEmpty) {
    runApp(const ProviderScope(child: MapMarkerApp()));
    return;
  }
  await KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  // 첫 화면(로그인 또는 여행 목록)을 정하려고 토큰을 먼저 읽는다. 로그인 화면이 깜빡이지 않는다.
  final authApi = AuthApi(createDio(Env.apiBaseUrl));
  final session = await AuthSession.restore(
    store: const SecureTokenStore(),
    api: authApi,
  );
  runApp(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWithValue(session),
        authApiProvider.overrideWithValue(authApi),
      ],
      child: const MapMarkerApp(),
    ),
  );
}

/// 글꼴 라이선스(OFL)는 글꼴과 함께 보여 줘야 한다. 앱의 라이선스 화면에 나온다.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['NanumSquareRound'], license);
  });
}

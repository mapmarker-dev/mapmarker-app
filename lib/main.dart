import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app/app.dart';
import 'config/env.dart';
import 'core/time/local_date.dart';
import 'data/trips/memory_trip_repository.dart';
import 'data/trips/trip_repository.dart';
import 'dev/sample_trips.dart';
import 'l10n/l10n.dart';

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
  final now = DateTime.now();
  final samples = sampleTrips(
    today: LocalDate.fromDateTime(now),
    now: now,
    l10n: lookupAppLocalizations(appLocale),
  );
  runApp(
    ProviderScope(
      overrides: [
        // 서버가 생기기 전에는 디버그 빌드에서 샘플 여행을 미리 넣는다.
        if (kDebugMode)
          tripRepositoryProvider.overrideWithValue(
            MemoryTripRepository(seed: samples.trips, seedStops: samples.stops),
          ),
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

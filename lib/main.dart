import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'config/env.dart';
import 'prototype/snapshot_lab_screen.dart';

/// 네이버 지도 SDK는 Android와 iOS만 지원한다.
bool get isMapSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isMapSupported && Env.naverMapClientId.isNotEmpty) {
    await FlutterNaverMap().init(
      clientId: Env.naverMapClientId,
      onAuthFailed: (ex) => log('네이버 지도 인증 실패: $ex'),
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: !isMapSupported
          ? const UnsupportedPlatformScreen()
          : Env.naverMapClientId.isEmpty
          ? const MissingEnvScreen()
          : const SnapshotLabScreen(),
    );
  }
}

class UnsupportedPlatformScreen extends StatelessWidget {
  const UnsupportedPlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('네이버 지도는 Android·iOS에서만 실행됩니다.')),
    );
  }
}

class MissingEnvScreen extends StatelessWidget {
  const MissingEnvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'NAVER_MAP_CLIENT_ID가 없습니다.\n'
            '.env를 채우고 flutter run --dart-define-from-file=.env 로 실행하세요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const _seoulCityHall = NLatLng(37.5666, 126.979);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NaverMap(
        options: NaverMapViewOptions(
          contentPadding: MediaQuery.paddingOf(context),
          initialCameraPosition: const NCameraPosition(
            target: _seoulCityHall,
            zoom: 14,
          ),
        ),
        onMapReady: (controller) {
          controller.addOverlay(
            NMarker(
              id: 'city_hall',
              position: _seoulCityHall,
              caption: const NOverlayCaption(text: '서울시청'),
            ),
          );
        },
      ),
    );
  }
}

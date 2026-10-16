import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'missing_env_screen.dart';
import 'router.dart';

class MapMarkerApp extends ConsumerWidget {
  const MapMarkerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Env.naverMapClientId.isEmpty) {
      return const MaterialApp(title: 'MapMarker', home: MissingEnvScreen());
    }
    return MaterialApp.router(
      title: 'MapMarker',
      // 한국어만 지원한다. 날짜 선택기 같은 Material 위젯도 한국어로 나온다.
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

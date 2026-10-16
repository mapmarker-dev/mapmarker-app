import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../l10n/l10n.dart';
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
      // 날짜 선택기 같은 Material 위젯도 앱과 같은 언어로 나온다.
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

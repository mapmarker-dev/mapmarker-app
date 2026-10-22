import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';
import 'missing_env_screen.dart';
import 'router.dart';

class MapMarkerApp extends ConsumerWidget {
  const MapMarkerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.light();
    if (Env.naverMapClientId.isEmpty) {
      return MaterialApp(
        title: 'MapMarker',
        theme: theme,
        home: const MissingEnvScreen(),
      );
    }
    return MaterialApp.router(
      title: 'MapMarker',
      theme: theme,
      // 날짜 선택기 같은 Material 위젯도 앱과 같은 언어로 나온다.
      locale: appLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

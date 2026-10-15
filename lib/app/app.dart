import 'package:flutter/material.dart';
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
      routerConfig: ref.watch(routerProvider),
    );
  }
}

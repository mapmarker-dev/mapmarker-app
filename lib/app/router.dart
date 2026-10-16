import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dev/snapshot_lab/snapshot_lab_screen.dart';
import '../features/trip_detail/trip_detail_screen.dart';
import '../features/trips/trip_create_screen.dart';
import '../features/trips/trip_list_screen.dart';
import 'routes.dart';

/// 앱의 경로 표.
///
/// 모든 화면을 여행 목록(`/`) 아래에 둔다. 딥링크로 바로 열어도 뒤로가기가 여행 목록으로 간다.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.tripList,
    routes: [
      GoRoute(
        path: Routes.tripList,
        builder: (context, state) => const TripListScreen(),
        routes: [
          GoRoute(
            path: 'trips/new',
            builder: (context, state) => const TripCreateScreen(),
          ),
          GoRoute(
            path: 'trips/:tripId',
            builder: (context, state) =>
                TripDetailScreen(tripId: state.pathParameters['tripId']!),
          ),
          if (kDebugMode)
            GoRoute(
              path: 'dev/snapshot-lab',
              builder: (context, state) => const SnapshotLabScreen(),
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

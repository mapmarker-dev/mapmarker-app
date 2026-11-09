import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_session.dart';
import '../dev/snapshot_lab/snapshot_lab_screen.dart';
import '../features/login/login_screen.dart';
import '../features/trip_detail/trip_detail_screen.dart';
import '../features/trips/trip_create_screen.dart';
import '../features/trips/trip_list_screen.dart';
import 'routes.dart';

/// 앱의 경로 표.
///
/// 모든 화면을 여행 목록(`/`) 아래에 둔다. 딥링크로 바로 열어도 뒤로가기가 여행 목록으로 간다.
/// 로그인(`/login`)만 최상위다. 아래에 두면 토큰 없이 여행 목록이 만들어지고, 뒤로가기가 앱을 닫지 못한다.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionProvider);
  final router = GoRouter(
    initialLocation: Routes.tripList,
    refreshListenable: session,
    redirect: (context, state) =>
        authRedirect(state.uri, loggedIn: session.isLoggedIn),
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
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

/// 로그인하지 않았으면 로그인 화면으로 보낸다. 가려던 곳(`/`가 아니면)은 `from`에 남긴다.
/// 로그인했는데 로그인 화면이면 `from`이나 여행 목록으로 보낸다.
String? authRedirect(Uri uri, {required bool loggedIn}) {
  final atLogin = uri.path == Routes.login;
  if (!loggedIn) {
    if (atLogin) return null;
    final from = uri.toString();
    if (from == Routes.tripList) return Routes.login;
    return Uri(path: Routes.login, queryParameters: {'from': from}).toString();
  }
  if (!atLogin) return null;
  return _appPath(uri.queryParameters['from']) ?? Routes.tripList;
}

/// 앱 안의 경로일 때만 돌려준다. 바깥 주소나 로그인 화면으로는 보내지 않는다.
String? _appPath(String? from) {
  if (from == null || !from.startsWith('/')) return null;
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path == Routes.login) return null;
  return from;
}

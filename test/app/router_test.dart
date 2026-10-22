import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/router.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/features/trips/trip_list_screen.dart';

import '../helpers/test_app.dart';

Widget _app() => ProviderScope(
  child: Consumer(
    builder: (context, ref, _) => testMaterialApp(ref.watch(routerProvider)),
  ),
);

void main() {
  testWidgets('starts at the trip list', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(TripListScreen), findsOneWidget);
    // 테스트는 디버그 모드로 돌아서 검증 화면 진입 버튼이 보인다.
    expect(find.byTooltip('스냅샷 검증'), findsOneWidget);
  });

  testWidgets('builds screens as Material pages', (tester) async {
    await tester.pumpWidget(_app());

    // go_router가 MaterialApp을 알아보지 못하면 전환 애니메이션 없는 페이지로 띄운다
    // (go_router 18 + package:flutter/material.dart 조합).
    final route = ModalRoute.of(tester.element(find.byType(TripListScreen)));
    expect(route?.settings, isA<MaterialPage<void>>());
  });

  test('snapshot lab sits under the trip list in debug builds', () {
    final container = ProviderContainer.test();
    final router = container.read(routerProvider);

    final match = router.configuration.findMatch(Uri.parse(Routes.snapshotLab));

    // 여행 목록 위에 검증 화면이 쌓인다. 뒤로가기를 누르면 여행 목록으로 간다.
    expect(match.matches.map((m) => m.matchedLocation), [
      Routes.tripList,
      Routes.snapshotLab,
    ]);
  });

  test('trip creation and trip pages sit under the trip list', () {
    final container = ProviderContainer.test();
    final router = container.read(routerProvider);

    final create = router.configuration.findMatch(Uri.parse(Routes.tripCreate));
    final trip = router.configuration.findMatch(Uri.parse(Routes.trip('abc')));

    expect(create.matches.map((m) => m.matchedLocation), [
      Routes.tripList,
      Routes.tripCreate,
    ]);
    // `new`를 여행 ID로 읽지 않는다.
    expect(create.pathParameters, isEmpty);
    expect(trip.matches.map((m) => m.matchedLocation), [
      Routes.tripList,
      '/trips/abc',
    ]);
    expect(trip.pathParameters['tripId'], 'abc');
  });
}

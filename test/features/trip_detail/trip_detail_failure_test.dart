import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_title_bar.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 1일차: a > b.
FlakyTripRepository _repository() => FlakyTripRepository(
  testRepository(
    [testTrip(id: 'jeju', region: '제주')],
    [
      testStop('a', tripId: 'jeju', kind: StopKind.tour),
      testStop('b', tripId: 'jeju', order: 1),
    ],
  ),
);

void main() {
  testWidgets('offers a retry when the trip cannot be loaded', (tester) async {
    final repository = _repository()..failLoads = ApiFailure.network;
    await pumpTestApp(
      tester,
      repository: repository,
      location: Routes.trip('jeju'),
    );

    expect(find.text(testL10n.tripLoadFailed), findsOneWidget);

    repository.failLoads = null;
    await tester.tap(find.text(testL10n.retry));
    await tester.pumpAndSettle();

    expect(find.byType(RouteTitleBar), findsOneWidget);
  });

  testWidgets('keeps the title and says so when renaming fails', (
    tester,
  ) async {
    final repository = _repository();
    await pumpTestApp(
      tester,
      repository: repository,
      location: Routes.trip('jeju'),
    );
    repository.failWrites = ApiFailure.server;

    await tester.tap(find.byTooltip('제목 바꾸기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '가족 여행',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('가족 여행'), findsNothing);
    expect(find.text(testL10n.saveFailed), findsOneWidget);
  });

  testWidgets('says the trip was reloaded when the server reports a conflict', (
    tester,
  ) async {
    final repository = _repository();
    await pumpTestApp(
      tester,
      repository: repository,
      location: Routes.trip('jeju'),
    );
    repository.failWrites = ApiFailure.conflict;

    await tester.tap(find.byTooltip('제목 바꾸기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text(testL10n.saveConflict), findsOneWidget);
  });

  testWidgets('limits the title to what the server accepts', (tester) async {
    await pumpTestApp(
      tester,
      repository: _repository(),
      location: Routes.trip('jeju'),
    );

    await tester.tap(find.byTooltip('제목 바꾸기'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(field.maxLength, 100);
  });

  testWidgets('drops the curve preview when saving the curve fails', (
    tester,
  ) async {
    final repository = _repository();
    tester.view.physicalSize =
        const Size(1280, 800) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final container = await pumpTestApp(
      tester,
      repository: repository,
      location: Routes.trip('jeju'),
    );
    await tester.tap(
      find.ancestor(
        of: find.text('1일차'),
        matching: find.byWidgetPredicate((w) => w is ChoiceChip),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ItinerarySegmentTile).first);
    await tester.pumpAndSettle();
    repository.failWrites = ApiFailure.network;

    final saved = await dragCurveHandle(tester, 0.35);

    expect(saved, isFalse);
    expect(find.text(testL10n.saveFailedNetwork), findsOneWidget);
    final route = container.read(tripRouteProvider('jeju')).value!;
    expect(route.segments.single.curvature, 0);

    repository.failWrites = null;
    expect(await dragCurveHandle(tester, 0.35), isTrue);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/route_curve.dart';
import 'package:mapmarker_app/core/theme/app_tokens.dart';
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
  group('while saving', _savingTests);

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
    // 도움말은 글자 수와 한 줄을 나눠 써서, 좁은 창에서도 잘리지 않게 두 줄까지 내려간다.
    expect(field.decoration!.helperMaxLines, 2);
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

/// 넓은 화면(오른쪽 패널)에서 1일차 목록을 연다.
Future<ProviderContainer> _openDayOne(
  WidgetTester tester,
  FlakyTripRepository repository,
) async {
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
  return container;
}

/// 저장을 기다리는 동안에는 진행 표시가 계속 돌아서 pumpAndSettle을 쓸 수 없다.
Future<void> _pumpWhileSaving(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

ItineraryStopTile _stopTile(WidgetTester tester, String id) => tester
    .widgetList<ItineraryStopTile>(find.byType(ItineraryStopTile))
    .singleWhere((tile) => tile.stop.id == id);

List<String> _stopIds(WidgetTester tester) => [
  for (final tile in tester.widgetList<ItineraryStopTile>(
    find.byType(ItineraryStopTile),
  ))
    tile.stop.id,
];

Finder _inStopTile(String id, Finder finder) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ItineraryStopTile && w.stop.id == id),
  matching: finder,
);

/// 1일차 a를 b 아래로 끌어 놓는다.
Future<void> _dragAUnderB(WidgetTester tester) async {
  await tester.tap(find.text('a'));
  await tester.pumpAndSettle();
  final handle = _inStopTile('a', find.byIcon(Icons.drag_handle));
  final drag = await tester.startGesture(tester.getCenter(handle));
  final rowHeight = tester.getSize(find.byKey(const ValueKey('b'))).height;
  await drag.moveBy(Offset(0, rowHeight / 2));
  await tester.pump();
  await drag.moveBy(Offset(0, rowHeight / 2 + 4));
  await tester.pump();
  await drag.up();
  await _pumpWhileSaving(tester);
}

void _savingTests() {
  testWidgets('dims a dragged stop and shows progress until it is saved', (
    tester,
  ) async {
    final repository = _repository()..holdWrites = Completer();
    await _openDayOne(tester, repository);

    await _dragAUnderB(tester);

    expect(_stopIds(tester), ['b', 'a']);
    expect(_stopTile(tester, 'a').saving, isTrue);
    expect(
      _inStopTile('a', find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    // 저장을 기다리는 동안에는 다시 끌 수 없다.
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    expect(_stopIds(tester), ['b', 'a']);
    expect(_stopTile(tester, 'a').saving, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('puts a dragged stop back when saving the move fails', (
    tester,
  ) async {
    final repository = _repository()
      ..holdWrites = Completer()
      ..failWrites = ApiFailure.network;
    await _openDayOne(tester, repository);
    await _dragAUnderB(tester);
    expect(_stopTile(tester, 'a').saving, isTrue);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    expect(_stopIds(tester), ['a', 'b']);
    expect(_stopTile(tester, 'a').saving, isFalse);
    expect(find.text(testL10n.saveFailedNetwork), findsOneWidget);
  });

  testWidgets('draws only the new curve, dimmed, until it is saved', (
    tester,
  ) async {
    final repository = _repository()..holdWrites = Completer();
    final container = await _openDayOne(tester, repository);
    await tester.tap(find.byType(ItinerarySegmentTile).first);
    await tester.pumpAndSettle();
    final route = container.read(tripRouteProvider('jeju')).value!;
    final a = route.stopById('a')!.position;
    final b = route.stopById('b')!.position;
    final color = mapScene(tester).lines.single.color;

    final saved = releaseCurveHandle(tester, 0.35);
    await _pumpWhileSaving(tester);

    final line = mapScene(tester).lines.single;
    expect(line.points, routeCurvePoints(a, b, 0.35));
    expect(line.color, color.withValues(alpha: AppOpacity.pending));
    // 흐린 선 위에 화살표만 또렷하게 남지 않는다.
    expect(mapScene(tester).arrows.where((a) => a.id == line.id), isEmpty);
    // 저장을 기다리는 동안에는 다시 끌 수 없다.
    expect(mapScene(tester).curveHandle, isNull);
    expect(
      tester.widget<ItinerarySegmentTile>(find.byType(ItinerarySegmentTile)),
      isA<ItinerarySegmentTile>().having((t) => t.saving, 'saving', isTrue),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    expect(await saved, isTrue);
    final after = mapScene(tester);
    expect(after.lines.single.points, routeCurvePoints(a, b, 0.35));
    expect(after.lines.single.color, color);
    expect(after.curveHandle?.curvature, 0.35);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('goes back to the old curve when saving the curve fails', (
    tester,
  ) async {
    final repository = _repository()
      ..holdWrites = Completer()
      ..failWrites = ApiFailure.network;
    final container = await _openDayOne(tester, repository);
    await tester.tap(find.byType(ItinerarySegmentTile).first);
    await tester.pumpAndSettle();
    final before = mapScene(tester);

    final saved = releaseCurveHandle(tester, 0.35);
    await _pumpWhileSaving(tester);
    expect(mapScene(tester).curveHandle, isNull);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    expect(await saved, isFalse);
    final after = mapScene(tester);
    expect(after.lines, before.lines);
    expect(after.curveHandle, before.curveHandle);
    expect(
      container
          .read(tripRouteProvider('jeju'))
          .value!
          .segments
          .single
          .curvature,
      0,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

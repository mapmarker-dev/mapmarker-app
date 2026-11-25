import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 1일차: a > b > c > d. a는 설명과 메모가 길어 펼치면 줄이 크다.
Future<ProviderContainer> _openDayOne(WidgetTester tester) async {
  tester.view.physicalSize =
      const Size(1280, 800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final long = List.filled(6, '해변을 따라 걷는 길').join(' ');
  final container = await pumpTestApp(
    tester,
    repository: testRepository(
      [testTrip(id: 'jeju', region: '제주', nights: 1)],
      [
        testStop('a', tripId: 'jeju').copyWith(description: long, memo: long),
        testStop('b', tripId: 'jeju', order: 1),
        testStop('c', tripId: 'jeju', order: 2),
        testStop('d', tripId: 'jeju', order: 3),
      ],
    ),
    location: Routes.trip('jeju'),
  );
  await tapChip(tester, '1일차');
  return container;
}

Future<void> _startReorder(WidgetTester tester) async {
  await tester.tap(find.text('순서 바꾸기'));
  await tester.pumpAndSettle();
}

Future<void> _tapDone(WidgetTester tester) async {
  await tester.tap(find.text('완료'));
  await tester.pumpAndSettle();
}

List<String> _shownIds(WidgetTester tester) => [
  for (final tile in tester.widgetList<ItineraryStopTile>(
    find.byType(ItineraryStopTile),
  ))
    tile.stop.id,
];

List<String> _savedIds(ProviderContainer container) => [
  for (final stop in container.read(tripRouteProvider('jeju')).value!.stops)
    stop.id,
];

Finder _tile(String id) =>
    find.byWidgetPredicate((w) => w is ItineraryStopTile && w.stop.id == id);

Finder _handleOf(String id) =>
    find.descendant(of: _tile(id), matching: find.byIcon(Icons.drag_handle));

/// [id]의 손잡이를 잡고 손가락을 [y]까지 조금씩 끌어 놓는다.
Future<void> _dragTo(WidgetTester tester, String id, double y) async {
  final from = tester.getCenter(_handleOf(id));
  final finger = await tester.startGesture(from);
  await tester.pump();
  for (var step = 1; step <= 10; step++) {
    await finger.moveTo(Offset(from.dx, from.dy + (y - from.dy) * step / 10));
    await tester.pump();
  }
  await finger.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows one-line rows with handles until cancelled', (
    tester,
  ) async {
    await _openDayOne(tester);
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();
    expect(tester.widget<ItineraryStopTile>(_tile('a')).expanded, isTrue);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byType(ItinerarySegmentTile), findsNWidgets(3));

    await _startReorder(tester);

    // 모든 줄이 접힌 한 줄 모양이고, 구간 줄과 버튼은 숨는다. 모든 장소에 손잡이가 있다.
    for (final id in ['a', 'b', 'c', 'd']) {
      final tile = tester.widget<ItineraryStopTile>(_tile(id));
      expect(tile.compact, isTrue);
      expect(tile.expanded, isFalse);
      expect(_handleOf(id), findsOneWidget);
    }
    expect(find.byType(ItinerarySegmentTile), findsNothing);
    expect(find.text('장소 넣기'), findsNothing);
    expect(find.byTooltip('장소 편집'), findsNothing);
    // 줄을 눌러도 펼치지 않는다.
    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(tester.widget<ItineraryStopTile>(_tile('b')).expanded, isFalse);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(tester.widget<ItineraryStopTile>(_tile('a')).compact, isFalse);
    expect(find.byType(ItinerarySegmentTile), findsNWidgets(3));
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.text('순서 바꾸기'), findsOneWidget);
  });

  testWidgets('drops a long stop exactly between the rows under the finger', (
    tester,
  ) async {
    final container = await _openDayOne(tester);
    await _startReorder(tester);

    // c 줄 가운데보다 조금 아래(c와 d 사이 쪽)까지 끈다.
    final c = tester.getRect(_tile('c'));
    await _dragTo(tester, 'a', c.center.dy + c.height / 4);

    expect(_shownIds(tester), ['b', 'c', 'a', 'd']);
    // [완료] 전에는 저장하지 않는다.
    expect(_savedIds(container), ['a', 'b', 'c', 'd']);

    await _tapDone(tester);

    expect(_savedIds(container), ['b', 'c', 'a', 'd']);
    expect(find.byType(ItinerarySegmentTile), findsNWidgets(3));
  });

  testWidgets('drops a stop dragged up between the rows under the finger', (
    tester,
  ) async {
    final container = await _openDayOne(tester);
    await _startReorder(tester);

    // b 줄 가운데보다 조금 위(a와 b 사이 쪽)까지 끈다.
    final b = tester.getRect(_tile('b'));
    await _dragTo(tester, 'd', b.center.dy - b.height / 4);
    await _tapDone(tester);

    expect(_savedIds(container), ['a', 'd', 'b', 'c']);
  });

  testWidgets('long-pressing a row also drags it', (tester) async {
    await _openDayOne(tester);
    await _startReorder(tester);
    final c = tester.getRect(_tile('c'));
    final from = tester.getCenter(find.text('a'));

    final finger = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var step = 1; step <= 10; step++) {
      final y = c.center.dy + c.height / 4;
      await finger.moveTo(Offset(from.dx, from.dy + (y - from.dy) * step / 10));
      await tester.pump();
    }
    await finger.up();
    await tester.pumpAndSettle();

    expect(_shownIds(tester), ['b', 'c', 'a', 'd']);
  });

  testWidgets('draws the new order on the map before it is saved', (
    tester,
  ) async {
    await _openDayOne(tester);
    await _startReorder(tester);
    final b = tester.getRect(_tile('b'));

    await _dragTo(tester, 'd', b.center.dy - b.height / 4);

    final scene = mapScene(tester);
    expect(scene.captions, ['a', 'd', 'b', 'c']);
    expect(scene.markers.map((m) => m.look.label), ['1', '2', '3', '4']);

    // 순서를 바꾸는 동안 지도를 눌러도 고르지 않는다.
    await tapMarker(tester, 'b');
    expect(tester.widget<ItineraryStopTile>(_tile('b')).highlighted, isFalse);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(mapScene(tester).captions, ['a', 'b', 'c', 'd']);
  });

  testWidgets('locks the day chips while reordering', (tester) async {
    await _openDayOne(tester);
    await _startReorder(tester);

    await tester.tap(
      find.widgetWithText(ChoiceChip, '전체'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('완료'), findsOneWidget);
    expect(mapScene(tester).captions, ['a', 'b', 'c', 'd']);
  });

  testWidgets('back ends reordering, asking first when the order changed', (
    tester,
  ) async {
    final container = await _openDayOne(tester);
    await _startReorder(tester);

    // 바꾼 것이 없으면 묻지 않고 끝낸다(화면은 그대로다).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('완료'), findsNothing);
    expect(find.text('순서 바꾸기'), findsOneWidget);

    await _startReorder(tester);
    final b = tester.getRect(_tile('b'));
    await _dragTo(tester, 'd', b.center.dy - b.height / 4);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('고친 내용을 버릴까요?'), findsOneWidget);

    // 취소하면 이어서 바꾼다.
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('취소')),
    );
    await tester.pumpAndSettle();

    expect(_shownIds(tester), ['a', 'd', 'b', 'c']);
    expect(find.text('완료'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('버리기'));
    await tester.pumpAndSettle();

    expect(_shownIds(tester), ['a', 'b', 'c', 'd']);
    expect(_savedIds(container), ['a', 'b', 'c', 'd']);
    expect(find.text('완료'), findsNothing);
  });
}

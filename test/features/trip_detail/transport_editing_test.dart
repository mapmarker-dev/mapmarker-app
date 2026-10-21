import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 1박 2일 여행. 1일차: a > b > 숙소.
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop('b', tripId: 'jeju', order: 1, kind: StopKind.food),
  testLodging('hotel', tripId: 'jeju', order: 2),
];

/// 태블릿 가로 화면. 일차 동선 목록이 지도 오른쪽 패널로 뜬다.
const _tablet = Size(1280, 800);

Future<(MemoryTripRepository, ProviderContainer)> _pumpJeju(
  WidgetTester tester, {
  Size screen = _tablet,
  List<TransportLeg> firstLegs = const [],
}) async {
  tester.view.physicalSize = screen * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final repository = testRepository([
    testTrip(id: 'jeju', region: '제주', nights: 1),
  ], _stops);
  if (firstLegs.isNotEmpty) {
    final route = (await tester.runAsync(
      () => repository.watchRoute('jeju').first,
    ))!;
    await repository.updateSegment(
      _segmentOf(route.segments, 'a', 'b').copyWith(legs: firstLegs),
    );
  }
  final container = await pumpTestApp(
    tester,
    repository: repository,
    location: Routes.trip('jeju'),
  );
  return (repository, container);
}

Segment _segmentOf(List<Segment> segments, String from, String to) =>
    segments.singleWhere((s) => s.fromStopId == from && s.toStopId == to);

/// 저장소에 있는 a → b 구간의 이동 수단.
List<TransportLeg> _savedLegs(ProviderContainer container) => _segmentOf(
  container.read(tripRouteProvider('jeju')).value!.segments,
  'a',
  'b',
).legs;

Future<void> _openDay1(WidgetTester tester) async {
  await tester.tap(
    find.ancestor(
      of: find.text('1일차'),
      matching: find.byWidgetPredicate((w) => w is ChoiceChip),
    ),
  );
  await tester.pumpAndSettle();
}

/// a → b 구간 줄.
Finder get _firstSegmentTile => find.byType(ItinerarySegmentTile).first;

/// a → b 구간 줄의 연필 아이콘. 목록에서 줄을 누른 뒤에만 뜬다.
Finder get _editButton => find.descendant(
  of: _firstSegmentTile,
  matching: find.byTooltip('이동 수단 고치기'),
);

/// a → b 구간 줄을 누르고, 뜬 연필 아이콘을 눌러 입력 화면을 연다.
Future<void> _tapEdit(WidgetTester tester) async {
  await tester.tap(_firstSegmentTile);
  await tester.pumpAndSettle();
  await tester.tap(_editButton);
  await tester.pumpAndSettle();
}

Future<void> _openForm(WidgetTester tester) async {
  await _openDay1(tester);
  await _tapEdit(tester);
}

Finder get _form => find.byType(Dialog);

Finder _inForm(Finder finder) => find.descendant(of: _form, matching: finder);

Future<void> _tapInForm(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 수단 칩을 눌러 토막을 맨 뒤에 잇는다.
Future<void> _addLeg(WidgetTester tester, String mode) =>
    _tapInForm(tester, _inForm(find.widgetWithText(ActionChip, mode)));

Finder _field(String text, {int leg = 0}) =>
    _inForm(find.widgetWithText(TextField, text)).at(leg);

Future<void> _enter(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Finder get _saveButton => _inForm(find.widgetWithText(TextButton, '저장'));

bool _canSave(WidgetTester tester) =>
    tester.widget<TextButton>(_saveButton).onPressed != null;

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_saveButton);
  await tester.pumpAndSettle();
}

/// 구간 줄의 글자. 아이콘 자리(U+FFFC)는 뺀다.
/// 구간 줄의 글자. 토막과 "+"가 각각 따로 된 글자라서 띄어쓰기로 잇는다.
String _tileText(WidgetTester tester) => _tileTexts(tester).join(' ');

/// 구간 줄의 글자 덩어리. 예: `['지하철 2정류장', '+', '도보']`.
List<String> _tileTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: _firstSegmentTile, matching: find.byType(Text)),
  ))
    text.data!,
];

void main() {
  testWidgets('tapping a segment row opens the transport form', (tester) async {
    await _pumpJeju(tester);

    await _openForm(tester);

    expect(_inForm(find.text('이동 수단')), findsOneWidget);
    expect(_inForm(find.text('a → b')), findsOneWidget);
    expect(_inForm(find.text('고르지 않으면 이동 수단 미정으로 둡니다.')), findsOneWidget);
    expect(_inForm(find.text('이동 수단 고르기')), findsOneWidget);
    expect(_inForm(find.byType(ActionChip)), findsNWidgets(7));
    // 고친 것이 없으면 저장할 것도 없지만, 저장해도 미정 그대로라 막지 않는다.
    expect(_canSave(tester), isTrue);
  });

  testWidgets('tapping the row itself only picks it', (tester) async {
    await _pumpJeju(tester);
    await _openDay1(tester);

    await tester.tap(find.text('이동 수단 미정').first);
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
    expect(
      tester.widget<ItinerarySegmentTile>(_firstSegmentTile).highlighted,
      isTrue,
    );
    // 누른 줄에만 연필이 뜬다.
    expect(_editButton, findsOneWidget);
    expect(find.byTooltip('이동 수단 고치기'), findsOneWidget);
  });

  testWidgets('shows no pencils until a row is tapped in the list', (
    tester,
  ) async {
    await _pumpJeju(tester);
    await _openDay1(tester);

    expect(find.byTooltip('이동 수단 고치기'), findsNothing);
    expect(find.byTooltip('장소 편집'), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });

  testWidgets('keeps the list clean when a line is picked on the map', (
    tester,
  ) async {
    final (_, container) = await _pumpJeju(tester);
    await _openDay1(tester);
    final segment = _segmentOf(
      container.read(tripRouteProvider('jeju')).value!.segments,
      'a',
      'b',
    );

    await tapLine(tester, segment.id);

    expect(
      tester.widget<ItinerarySegmentTile>(_firstSegmentTile).highlighted,
      isTrue,
    );
    expect(find.byTooltip('이동 수단 고치기'), findsNothing);
  });

  testWidgets('spaces wrapped transfer lines apart', (tester) async {
    await _pumpJeju(
      tester,
      firstLegs: const [
        TransportLeg(TransportMode.flight, duration: Duration(hours: 1)),
        TransportLeg(
          TransportMode.subway,
          stopCount: 5,
          duration: Duration(minutes: 19),
        ),
        TransportLeg(TransportMode.walk, duration: Duration(minutes: 20)),
        TransportLeg(
          TransportMode.bus,
          stopCount: 2,
          duration: Duration(minutes: 6),
        ),
      ],
    );
    await _openDay1(tester);

    final text = tester.widget<Text>(
      find.descendant(of: _firstSegmentTile, matching: find.byType(Text)).first,
    );
    final fontSize = text.style!.fontSize!;
    expect(text.style!.height, greaterThanOrEqualTo(1.6));
    // 줄 높이가 글자 크기보다 넉넉하다(아이콘 16px도 들어간다).
    expect(fontSize * text.style!.height!, greaterThan(16 + 2));
  });

  testWidgets('wraps a long transfer only between legs and pluses', (
    tester,
  ) async {
    await _pumpJeju(
      tester,
      firstLegs: const [
        TransportLeg(TransportMode.flight, duration: Duration(hours: 1)),
        TransportLeg(TransportMode.walk, duration: Duration(minutes: 20)),
        TransportLeg(
          TransportMode.subway,
          stopCount: 3,
          duration: Duration(minutes: 10),
        ),
        TransportLeg(TransportMode.walk, duration: Duration(minutes: 20)),
      ],
    );
    await _openDay1(tester);

    // 토막(아이콘 + 글자)과 "+"가 각각 한 덩어리다.
    expect(_tileTexts(tester), [
      '비행기 1시간',
      '+',
      '도보 20분',
      '+',
      '지하철 3정류장 10분',
      '+',
      '도보 20분',
    ]);

    final texts = find.descendant(
      of: _firstSegmentTile,
      matching: find.byType(Text),
    );
    final lineHeight =
        tester.widget<Text>(texts.first).style!.fontSize! *
        tester.widget<Text>(texts.first).style!.height!;
    final tops = {
      for (final element in texts.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    };
    // 패널 폭에 다 들어가지 않아 여러 줄이 된다.
    expect(tops.length, greaterThan(1));
    // 그래도 덩어리 하나는 한 줄 안에 있다(중간에 끊기지 않는다).
    for (final element in texts.evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).height,
        lineHeight,
        reason: (element.widget as Text).data,
      );
    }
    // 수단 아이콘은 자기 토막 글자와 같은 줄에 있다.
    final subwayIcon = find.descendant(
      of: _firstSegmentTile,
      matching: find.byIcon(Icons.subway),
    );
    final subwayText = find.descendant(
      of: _firstSegmentTile,
      matching: find.text('지하철 3정류장 10분'),
    );
    expect(
      tester.getCenter(subwayIcon).dy,
      moreOrLessEquals(tester.getCenter(subwayText).dy, epsilon: 1),
    );
  });

  testWidgets('the pencil picks the row and opens the form', (tester) async {
    await _pumpJeju(tester);

    await _openForm(tester);

    expect(_form, findsOneWidget);
    expect(
      tester.widget<ItinerarySegmentTile>(_firstSegmentTile).highlighted,
      isTrue,
    );
  });

  testWidgets('saves a transfer and shows it with icons in the row', (
    tester,
  ) async {
    final (_, container) = await _pumpJeju(tester);
    await _openForm(tester);

    await _addLeg(tester, '지하철');
    await _enter(tester, _field('정류장 수'), '2');
    expect(_inForm(find.text('갈아타기 추가')), findsOneWidget);
    await _addLeg(tester, '도보');
    await _enter(tester, _field('분', leg: 1), '5');
    await _save(tester);

    expect(_savedLegs(container), const [
      TransportLeg(TransportMode.subway, stopCount: 2),
      TransportLeg(TransportMode.walk, duration: Duration(minutes: 5)),
    ]);
    expect(_form, findsNothing);
    expect(_tileText(tester), contains('지하철 2정류장 + '));
    expect(_tileText(tester), contains('도보 5분'));
    expect(
      find.descendant(
        of: _firstSegmentTile,
        matching: find.byIcon(Icons.subway),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _firstSegmentTile,
        matching: find.byIcon(Icons.directions_walk),
      ),
      findsOneWidget,
    );
    // 누른 구간 줄은 고른 채로 남는다.
    expect(
      tester.widget<ItinerarySegmentTile>(_firstSegmentTile).highlighted,
      isTrue,
    );
  });

  testWidgets('writes a long ride as hours and minutes', (tester) async {
    final (_, container) = await _pumpJeju(tester);
    await _openForm(tester);

    await _addLeg(tester, '비행기');
    await _enter(tester, _field('시간'), '3');
    await _enter(tester, _field('분'), '20');
    await _save(tester);

    expect(_savedLegs(container), const [
      TransportLeg(
        TransportMode.flight,
        duration: Duration(hours: 3, minutes: 20),
      ),
    ]);
    expect(_tileText(tester), contains('비행기 3시간 20분'));
  });

  testWidgets('does not save numbers out of range', (tester) async {
    final (_, container) = await _pumpJeju(tester);
    await _openForm(tester);
    await _addLeg(tester, '버스');

    await _enter(tester, _field('정류장 수'), '0');
    expect(_inForm(find.text('1~99 사이로 적어 주세요.')), findsOneWidget);
    expect(_canSave(tester), isFalse);

    await _enter(tester, _field('정류장 수'), '3');
    await _enter(tester, _field('분'), '75');
    expect(_inForm(find.text('0~59 사이로 적어 주세요.')), findsOneWidget);
    expect(_canSave(tester), isFalse);

    await _enter(tester, _field('분'), '45');
    expect(_canSave(tester), isTrue);
    await _save(tester);

    expect(_savedLegs(container), const [
      TransportLeg(
        TransportMode.bus,
        stopCount: 3,
        duration: Duration(minutes: 45),
      ),
    ]);
  });

  testWidgets('takes only digits', (tester) async {
    await _pumpJeju(tester);
    await _openForm(tester);
    await _addLeg(tester, '지하철');

    await _enter(tester, _field('정류장 수'), '1a2b3');

    expect(tester.widget<TextField>(_field('정류장 수')).controller!.text, '12');
  });

  testWidgets('asks for stops only on subway and bus', (tester) async {
    final (_, container) = await _pumpJeju(tester);
    await _openForm(tester);
    await _addLeg(tester, '지하철');
    await _enter(tester, _field('정류장 수'), '4');

    await _tapInForm(tester, find.byTooltip('수단 바꾸기'));
    await tester.tap(find.text('기차').last);
    await tester.pumpAndSettle();

    expect(_inForm(find.widgetWithText(TextField, '정류장 수')), findsNothing);
    await _save(tester);
    // 기차로 바꾸면 적어 둔 정류장 수는 저장하지 않는다.
    expect(_savedLegs(container), const [TransportLeg(TransportMode.train)]);
  });

  testWidgets('keeps typed stops while switching modes back and forth', (
    tester,
  ) async {
    await _pumpJeju(tester);
    await _openForm(tester);
    await _addLeg(tester, '버스');
    await _enter(tester, _field('정류장 수'), '4');

    for (final mode in ['도보', '버스']) {
      await _tapInForm(tester, find.byTooltip('수단 바꾸기'));
      await tester.tap(find.text(mode).last);
      await tester.pumpAndSettle();
    }

    expect(tester.widget<TextField>(_field('정류장 수')).controller!.text, '4');
  });

  testWidgets('reorders and deletes legs', (tester) async {
    final (_, container) = await _pumpJeju(
      tester,
      firstLegs: const [
        TransportLeg(TransportMode.subway, stopCount: 2),
        TransportLeg(TransportMode.walk),
      ],
    );
    await _openForm(tester);
    expect(_inForm(find.byTooltip('앞으로 옮기기')), findsNWidgets(2));

    // 맨 앞 토막은 앞으로, 맨 뒤 토막은 뒤로 옮길 수 없다.
    IconButton button(String tooltip, int leg) => tester.widget<IconButton>(
      _inForm(
        find.widgetWithIcon(IconButton, switch (tooltip) {
          '앞' => Icons.arrow_upward,
          _ => Icons.arrow_downward,
        }),
      ).at(leg),
    );
    expect(button('앞', 0).onPressed, isNull);
    expect(button('뒤', 1).onPressed, isNull);

    await _tapInForm(tester, _inForm(find.byTooltip('뒤로 옮기기')).first);
    // 적어 둔 정류장 수도 지하철 토막을 따라간다.
    expect(tester.widget<TextField>(_field('정류장 수')).controller!.text, '2');
    await _save(tester);
    expect(_savedLegs(container), const [
      TransportLeg(TransportMode.walk),
      TransportLeg(TransportMode.subway, stopCount: 2),
    ]);

    await _tapEdit(tester);
    await _tapInForm(tester, _inForm(find.byTooltip('이 수단 지우기')).first);
    await _tapInForm(tester, _inForm(find.byTooltip('이 수단 지우기')).first);
    await _save(tester);

    expect(_savedLegs(container), isEmpty);
    expect(_tileText(tester), '이동 수단 미정');
  });

  testWidgets('opens with the saved legs', (tester) async {
    await _pumpJeju(
      tester,
      firstLegs: const [
        TransportLeg(
          TransportMode.ferry,
          duration: Duration(hours: 1, minutes: 40),
        ),
      ],
    );

    await _openForm(tester);

    expect(_inForm(find.text('배')), findsWidgets);
    expect(tester.widget<TextField>(_field('시간')).controller!.text, '1');
    expect(tester.widget<TextField>(_field('분')).controller!.text, '40');
    expect(_inForm(find.text('갈아타기 추가')), findsOneWidget);
  });

  testWidgets('stops offering modes after five legs', (tester) async {
    await _pumpJeju(tester);
    await _openForm(tester);

    for (var i = 0; i < 5; i++) {
      await _addLeg(tester, '도보');
    }

    final notice = _inForm(find.text('한 구간에는 수단을 5개까지 이을 수 있습니다.'));
    await tester.scrollUntilVisible(
      notice,
      200,
      scrollable: _inForm(find.byType(Scrollable)).first,
    );
    expect(notice, findsOneWidget);
    expect(_inForm(find.byType(ActionChip)), findsNothing);
  });

  testWidgets('asks before throwing away changes', (tester) async {
    final (_, container) = await _pumpJeju(tester);
    await _openForm(tester);
    await _addLeg(tester, '차');

    await tester.tap(_inForm(find.byTooltip('닫기')));
    await tester.pumpAndSettle();
    expect(find.text('고친 내용을 버릴까요?'), findsOneWidget);

    await tester.tap(find.text('버리기'));
    await tester.pumpAndSettle();

    expect(_form, findsNothing);
    expect(_savedLegs(container), isEmpty);
  });

  testWidgets('closes without asking when nothing changed', (tester) async {
    await _pumpJeju(tester);
    await _openForm(tester);

    await tester.tap(_inForm(find.byTooltip('닫기')));
    await tester.pumpAndSettle();

    expect(find.text('고친 내용을 버릴까요?'), findsNothing);
    expect(_form, findsNothing);
  });

  testWidgets('opens from the bottom sheet on a portrait phone', (
    tester,
  ) async {
    final (_, container) = await _pumpJeju(
      tester,
      screen: const Size(412, 915),
    );
    await _openDay1(tester);
    await tester.drag(
      find.textContaining(RegExp('장소 ')).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await _tapEdit(tester);
    await _addLeg(tester, '도보');
    await _enter(tester, _field('분'), '15');
    await _save(tester);

    expect(_savedLegs(container), const [
      TransportLeg(TransportMode.walk, duration: Duration(minutes: 15)),
    ]);
    expect(_tileText(tester), contains('도보 15분'));
  });

  group('moving a stop', () {
    /// 1일차 목록에서 b를 누르고, 뜬 손잡이로 a 위로 끈다(a > b > 숙소 → b > a > 숙소).
    Future<void> dragBAboveA(WidgetTester tester) async {
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      final handle = find.descendant(
        of: find.byKey(const ValueKey('b')),
        matching: find.byIcon(Icons.drag_handle),
      );
      final rowHeight = tester.getSize(find.byKey(const ValueKey('a'))).height;
      final drag = await tester.startGesture(tester.getCenter(handle));
      await drag.moveBy(Offset(0, -rowHeight / 2));
      await tester.pump();
      await drag.moveBy(Offset(0, -rowHeight / 2 - 4));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
    }

    List<String> savedOrder(ProviderContainer container) => [
      for (final stop in container.read(tripRouteProvider('jeju')).value!.stops)
        stop.id,
    ];

    List<String> listedOrder(WidgetTester tester) => [
      for (final tile in tester.widgetList<ItineraryStopTile>(
        find.byType(ItineraryStopTile, skipOffstage: false),
      ))
        tile.stop.id,
    ];

    const legs = [TransportLeg(TransportMode.subway, stopCount: 2)];

    testWidgets('asks before dropping a chosen transport', (tester) async {
      await _pumpJeju(tester, firstLegs: legs);
      await _openDay1(tester);

      await dragBAboveA(tester);

      expect(find.text('이동 수단이 사라집니다'), findsOneWidget);
      expect(find.text('1일차 a → b'), findsOneWidget);
      expect(find.text('지하철 2정류장'), findsWidgets);
    });

    testWidgets('puts the stop back when cancelled', (tester) async {
      final (_, container) = await _pumpJeju(tester, firstLegs: legs);
      await _openDay1(tester);
      await dragBAboveA(tester);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(savedOrder(container), ['a', 'b', 'hotel']);
      expect(listedOrder(tester), ['a', 'b', 'hotel']);
      expect(_savedLegs(container), legs);
    });

    testWidgets('moves the stop and drops the transport when confirmed', (
      tester,
    ) async {
      final (_, container) = await _pumpJeju(tester, firstLegs: legs);
      await _openDay1(tester);
      await dragBAboveA(tester);

      await tester.tap(find.text('옮기기'));
      await tester.pumpAndSettle();

      expect(savedOrder(container), ['b', 'a', 'hotel']);
      expect(listedOrder(tester), ['b', 'a', 'hotel']);
      final segments = container
          .read(tripRouteProvider('jeju'))
          .value!
          .segments;
      expect(segments.every((s) => s.legs.isEmpty), isTrue);
    });

    testWidgets('moves without asking when no transport is chosen', (
      tester,
    ) async {
      final (_, container) = await _pumpJeju(tester);
      await _openDay1(tester);

      await dragBAboveA(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(savedOrder(container), ['b', 'a', 'hotel']);
    });
  });

  group('moving a stop to another day in its form', () {
    const legs = [TransportLeg(TransportMode.subway, stopCount: 2)];

    /// 1일차 목록에서 b의 입력 화면을 열고 일차를 2일차로 바꾼 뒤 저장을 누른다.
    Future<void> moveBToDay2(WidgetTester tester) async {
      await _openDay1(tester);
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('장소 편집'));
      await tester.pumpAndSettle();
      final dayField = _inForm(find.byType(DropdownButtonFormField<int>));
      await tester.ensureVisible(dayField);
      await tester.pumpAndSettle();
      await tester.tap(dayField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2일차').last);
      await tester.pumpAndSettle();
      await tester.tap(_saveButton.first);
      await tester.pumpAndSettle();
    }

    List<(String, int)> savedDays(ProviderContainer container) => [
      for (final stop in container.read(tripRouteProvider('jeju')).value!.stops)
        (stop.id, stop.day),
    ];

    testWidgets('asks before dropping a chosen transport', (tester) async {
      await _pumpJeju(tester, firstLegs: legs);

      await moveBToDay2(tester);

      expect(find.text('이동 수단이 사라집니다'), findsOneWidget);
      expect(find.text('1일차 a → b'), findsOneWidget);
    });

    testWidgets('stays in the form when cancelled', (tester) async {
      final (_, container) = await _pumpJeju(tester, firstLegs: legs);
      await moveBToDay2(tester);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      // 입력 화면에 남아 일차를 다시 고칠 수 있다. 저장소는 그대로다.
      expect(find.text('장소 편집'), findsWidgets);
      expect(find.byType(AlertDialog), findsNothing);
      expect(savedDays(container), [('a', 1), ('b', 1), ('hotel', 1)]);
      expect(_savedLegs(container), legs);
    });

    testWidgets('moves the stop when confirmed', (tester) async {
      final (_, container) = await _pumpJeju(tester, firstLegs: legs);
      await moveBToDay2(tester);

      await tester.tap(find.text('옮기기'));
      await tester.pumpAndSettle();

      expect(find.text('장소 편집'), findsNothing);
      expect(savedDays(container), [('a', 1), ('hotel', 1), ('b', 2)]);
      final segments = container
          .read(tripRouteProvider('jeju'))
          .value!
          .segments;
      expect(segments.every((s) => s.legs.isEmpty), isTrue);
    });

    testWidgets('moves without asking when no transport is chosen', (
      tester,
    ) async {
      final (_, container) = await _pumpJeju(tester);

      await moveBToDay2(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(savedDays(container), [('a', 1), ('hotel', 1), ('b', 2)]);
    });
  });
}

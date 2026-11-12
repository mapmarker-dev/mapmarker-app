import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/stop_form_dialog.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 1박 2일 여행. 1일차: a > b(오전 10:00) > 숙소, 2일차: c. 후보: 우도.
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop(
    'b',
    tripId: 'jeju',
    order: 1,
  ).copyWith(plannedTime: () => const LocalTime(10, 0)),
  testLodging('hotel', tripId: 'jeju', order: 2),
  testStop('c', tripId: 'jeju', day: 2),
];

const _udo = Candidate(
  id: 'udo',
  tripId: 'jeju',
  latitude: 33.5,
  longitude: 126.95,
  name: '우도',
  kind: StopKind.tour,
  description: '섬',
  memo: '배 시간 확인',
);

const _walk = [TransportLeg(TransportMode.walk)];

/// [legs]는 (출발 장소, 도착 장소) 구간에 미리 적어 둘 이동 수단이다.
Future<(ProviderContainer, FlakyTripRepository)> _pump(
  WidgetTester tester, {
  Map<(String, String), List<TransportLeg>> legs = const {},
}) async {
  final MemoryTripRepository memory = testRepository(
    [testTrip(id: 'jeju', region: '제주', nights: 1)],
    _stops,
    [_udo],
  );
  if (legs.isNotEmpty) {
    final route = (await tester.runAsync(
      () => memory.watchRoute('jeju').first,
    ))!;
    for (final MapEntry(key: (from, to), value: written) in legs.entries) {
      await memory.updateSegment(
        route.segments
            .singleWhere((s) => s.fromStopId == from && s.toStopId == to)
            .copyWith(legs: written),
      );
    }
  }
  final repository = FlakyTripRepository(memory);
  final container = await pumpTestApp(
    tester,
    repository: repository,
    location: Routes.trip('jeju'),
  );
  return (container, repository);
}

TripRoute _route(ProviderContainer container) =>
    container.read(tripRouteProvider('jeju')).value!;

RouteChoice _choice(ProviderContainer container) =>
    container.read(routeChoiceProvider('jeju'));

Finder get _form => find.byType(StopFormDialog);

Finder _inForm(Finder finder) => find.descendant(of: _form, matching: finder);

Finder get _save => _inForm(find.widgetWithText(TextButton, '저장'));

Finder get _demote => _inForm(find.widgetWithText(OutlinedButton, '후보로 빼기'));

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

/// 입력 화면은 길어서 아래 버튼은 넘겨야 만들어진다.
Future<void> _tapInForm(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: _inForm(find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// "후보" 보기에서 [name] 후보 줄을 펼치고 [동선에 넣기]를 누른다.
Future<void> _openPromote(WidgetTester tester, String name) async {
  await tapChip(tester, '후보');
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, '동선에 넣기'));
  await tester.pumpAndSettle();
}

/// [day] 보기에서 [name] 장소 줄을 누르고 연필로 장소 입력 화면을 연다.
Future<void> _openEditor(WidgetTester tester, String day, String name) async {
  await tapChip(tester, day);
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('장소 편집'));
  await tester.pumpAndSettle();
}

ItineraryStopTile _stopTile(WidgetTester tester, String id) =>
    tester.widget<ItineraryStopTile>(
      find.byWidgetPredicate(
        (w) => w is ItineraryStopTile && w.stop.id == id,
        skipOffstage: false,
      ),
    );

CandidateTile _candidateTile(WidgetTester tester, String id) =>
    tester.widget<CandidateTile>(
      find.byWidgetPredicate(
        (w) => w is CandidateTile && w.candidate.id == id,
        skipOffstage: false,
      ),
    );

void main() {
  group('adding a candidate to the route', () {
    testWidgets('opens the stop form filled from the candidate, '
        'then shows it on its day', (tester) async {
      final (container, _) = await _pump(tester);
      await _openPromote(tester, '우도');

      expect(_form, findsOneWidget);
      expect(_inForm(find.text('동선에 넣기')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(_inForm(find.widgetWithText(TextField, '이름')))
            .controller!
            .text,
        '우도',
      );
      expect(_inForm(find.text('섬')), findsOneWidget);
      expect(_inForm(find.text('배 시간 확인')), findsOneWidget);
      // 새 장소처럼 일차와 넣을 자리를 고른다. 일차는 장소가 있는 마지막 일차다.
      expect(_inForm(find.text('2일차')), findsOneWidget);
      expect(_inForm(find.text('넣을 자리')), findsOneWidget);

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_form, findsNothing);
      final route = _route(container);
      expect(route.candidates, isEmpty);
      final placed = route.stopById('udo')!;
      expect((placed.day, placed.order), (2, 1));
      expect(placed.kind, StopKind.tour);
      expect(placed.memo, '배 시간 확인');
      expect(placed.position, _udo.position);
      // 그 일차로 가서 넣은 장소를 보여 준다.
      expect(_choice(container).day, 2);
      expect(_stopTile(tester, 'udo').highlighted, isTrue);
      expect(mapScene(tester).markers.where((m) => m.secondary), isEmpty);
    });

    testWidgets('offers the button on a row opened from the map', (
      tester,
    ) async {
      await _pump(tester);
      await tapMarker(tester, 'udo');

      expect(find.widgetWithText(FilledButton, '동선에 넣기'), findsOneWidget);
    });

    testWidgets('warns about transports dropped by the chosen place', (
      tester,
    ) async {
      final (container, _) = await _pump(tester, legs: {('b', 'hotel'): _walk});
      await _openPromote(tester, '우도');

      await _tapInForm(
        tester,
        _inForm(find.widgetWithText(DropdownButtonFormField<int>, '일차')),
      );
      await tester.tap(find.text('1일차').last);
      await tester.pumpAndSettle();

      // 기본 자리는 그날 밤 숙소 앞이라 b → 숙소 사이에 끼어든다.
      expect(_inForm(find.text('이 자리에 넣으면 아래 이동 수단이 지워집니다.')), findsOneWidget);
      expect(_inForm(find.text('1일차 b → hotel')), findsOneWidget);

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_route(container).stops.map((s) => s.id), [
        'a',
        'b',
        'udo',
        'hotel',
        'c',
      ]);
    });

    testWidgets('says when it went in as lodging while lodging is hidden', (
      tester,
    ) async {
      final (container, _) = await _pump(tester);
      await tapChip(tester, '숙소');
      await _openPromote(tester, '우도');
      await _tapInForm(tester, _inForm(find.widgetWithText(ChoiceChip, '숙소')));

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_choice(container).day, 2);
      expect(find.text('숙소가 꺼져 있어 지도에 보이지 않습니다.'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, '숙소 켜기'));
      await tester.pumpAndSettle();

      expect(_stopTile(tester, 'udo').highlighted, isTrue);
    });

    testWidgets('keeps the form open when saving fails, '
        'then puts the same candidate', (tester) async {
      final (container, repository) = await _pump(tester);
      await _openPromote(tester, '우도');
      repository.failWrites = ApiFailure.network;

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_form, findsOneWidget);
      expect(_inForm(find.text(testL10n.saveFailedNetwork)), findsOneWidget);
      expect(_route(container).candidates, hasLength(1));

      repository.failWrites = null;
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_form, findsNothing);
      expect(_route(container).stopById('udo'), isNotNull);
      expect(_route(container).candidates, isEmpty);
    });
  });

  group('moving a stop to the candidates', () {
    testWidgets('moves it straight away when nothing is lost, '
        'then offers to show it', (tester) async {
      final (container, _) = await _pump(tester);
      await _openEditor(tester, '1일차', 'a');

      await _tapInForm(tester, _demote);

      expect(find.byType(AlertDialog), findsNothing);
      expect(_form, findsNothing);
      final route = _route(container);
      expect(route.stops.map((s) => s.id), ['b', 'hotel', 'c']);
      expect(route.candidates.map((c) => c.id), ['udo', 'a']);
      expect(route.candidateById('a')!.kind, StopKind.tour);
      expect(find.text('a 장소를 후보로 뺐습니다.'), findsOneWidget);
      // 보기는 그대로다.
      expect(_choice(container).day, 1);

      await tester.tap(find.widgetWithText(SnackBarAction, '후보 보기'));
      await tester.pumpAndSettle();

      expect(_choice(container).candidateView, isTrue);
      expect(_candidateTile(tester, 'a').highlighted, isTrue);
      expect(_candidateTile(tester, 'a').expanded, isTrue);
    });

    testWidgets('asks first when a planned time or a written transport goes', (
      tester,
    ) async {
      final (container, _) = await _pump(tester, legs: {('a', 'b'): _walk});
      await _openEditor(tester, '1일차', 'b');

      await _tapInForm(tester, _demote);

      expect(find.text('b 후보로 빼기'), findsOneWidget);
      expect(_inDialog(find.text('예정 시각 오전 10:00')), findsOneWidget);
      expect(_inDialog(find.text('1일차 a → b')), findsOneWidget);
      expect(_inDialog(find.text('도보')), findsOneWidget);

      await tester.tap(_inDialog(find.text('취소')));
      await tester.pumpAndSettle();

      expect(_form, findsOneWidget);
      expect(_route(container).stopById('b'), isNotNull);

      await _tapInForm(tester, _demote);
      await tester.tap(_inDialog(find.text('빼기')));
      await tester.pumpAndSettle();

      expect(_form, findsNothing);
      final route = _route(container);
      expect(route.stopById('b'), isNull);
      expect(route.candidateById('b'), isNotNull);
      // 앞뒤 장소는 새 구간으로 이어진다.
      expect(
        route.segments.any((s) => s.fromStopId == 'a' && s.toStopId == 'hotel'),
        isTrue,
      );
    });

    testWidgets('does not ask about a planned time cleared in the form', (
      tester,
    ) async {
      final (container, _) = await _pump(tester);
      await _openEditor(tester, '1일차', 'b');
      await _tapInForm(tester, _inForm(find.byTooltip('예정 시각 지우기')));

      await _tapInForm(tester, _demote);

      expect(find.byType(AlertDialog), findsNothing);
      expect(_route(container).candidateById('b'), isNotNull);
    });

    testWidgets('takes the edited name and notes along', (tester) async {
      final (container, _) = await _pump(tester);
      await _openEditor(tester, '1일차', 'a');
      await tester.enterText(
        _inForm(find.widgetWithText(TextField, '이름')),
        '협재',
      );
      await tester.pump();

      await _tapInForm(tester, _demote);

      expect(_route(container).candidateById('a')!.name, '협재');
      expect(find.text('협재 장소를 후보로 뺐습니다.'), findsOneWidget);
    });

    testWidgets('cannot move without a name', (tester) async {
      await _pump(tester);
      await _openEditor(tester, '1일차', 'a');
      await tester.enterText(
        _inForm(find.widgetWithText(TextField, '이름')),
        ' ',
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        _demote,
        200,
        scrollable: _inForm(find.byType(Scrollable)).first,
      );

      expect(tester.widget<OutlinedButton>(_demote).onPressed, isNull);
    });

    testWidgets('has no button on the start of the day', (tester) async {
      await _pump(tester);
      await _openEditor(tester, '2일차', 'hotel');

      expect(_form, findsOneWidget);
      expect(_demote, findsNothing);
      expect(_inForm(find.text('장소 지우기')), findsNothing);
    });

    testWidgets('keeps the form open when moving fails, then moves', (
      tester,
    ) async {
      final (container, repository) = await _pump(tester);
      await _openEditor(tester, '1일차', 'a');
      repository.failWrites = ApiFailure.network;

      await _tapInForm(tester, _demote);

      expect(_form, findsOneWidget);
      expect(_inForm(find.text(testL10n.saveFailedNetwork)), findsOneWidget);
      expect(_route(container).stopById('a'), isNotNull);

      repository.failWrites = null;
      await _tapInForm(tester, _demote);

      expect(_form, findsNothing);
      expect(_route(container).candidateById('a'), isNotNull);
    });
  });
}

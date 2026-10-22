import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/route_scene.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 2박 3일 여행.
/// 1일차: a > b > 숙소, 2일차: c > d(14:30) > 숙소(연박, 같은 자리), 3일차: 없음.
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop('b', tripId: 'jeju', order: 1, kind: StopKind.food),
  testLodging('hotel', tripId: 'jeju', order: 2),
  testStop(
    'c',
    tripId: 'jeju',
    day: 2,
  ).copyWith(description: '바다 보며 산책', memo: '주차 2시간 무료'),
  testStop(
    'd',
    tripId: 'jeju',
    day: 2,
    order: 1,
    kind: StopKind.tour,
  ).copyWith(plannedTime: () => const LocalTime(14, 30)),
  testLodging('hotel2', tripId: 'jeju', day: 2, order: 2),
];

const _somewhere = LatLng(33.40, 126.60);
const _elsewhere = LatLng(33.30, 126.70);

const _subway = [TransportLeg(TransportMode.subway, stopCount: 2)];
const _walk = [TransportLeg(TransportMode.walk)];

/// [legs]는 (출발 장소, 도착 장소) 구간에 미리 적어 둘 이동 수단이다.
Future<ProviderContainer> _pumpJeju(
  WidgetTester tester, {
  List<Stop>? stops,
  Map<(String, String), List<TransportLeg>> legs = const {},
}) async {
  // 입력 화면과 펼친 시트가 모두 보이게 화면을 키운다.
  tester.view.physicalSize =
      const Size(800, 1800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final repository = testRepository([
    testTrip(id: 'jeju', region: '제주', nights: 2),
  ], stops ?? _stops);
  if (legs.isNotEmpty) {
    final route = (await tester.runAsync(
      () => repository.watchRoute('jeju').first,
    ))!;
    for (final MapEntry(key: (from, to), value: written) in legs.entries) {
      await repository.updateSegment(
        _segmentOf(route.segments, from, to).copyWith(legs: written),
      );
    }
  }
  return pumpTestApp(
    tester,
    repository: repository,
    location: Routes.trip('jeju'),
  );
}

Segment _segmentOf(Iterable<Segment> segments, String from, String to) =>
    segments.singleWhere((s) => s.fromStopId == from && s.toStopId == to);

/// 저장소에 있는 구간.
Iterable<Segment> _savedSegments(ProviderContainer container) =>
    container.read(tripRouteProvider('jeju')).value!.segments;

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (w) => w is ChoiceChip || w is FilterChip,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.drag(
    find.textContaining(RegExp('장소 ')).last,
    const Offset(0, -1600),
  );
  await tester.pumpAndSettle();
}

MapMarker? _draft(WidgetTester tester) =>
    mapScene(tester).markers.where((m) => m.id == draftMarkerId).firstOrNull;

Finder get _form => find.byType(Dialog);

Finder _inForm(Finder finder) => find.descendant(of: _form, matching: finder);

Finder get _nameField => _inForm(find.widgetWithText(TextField, '이름'));

Finder get _saveButton => _inForm(find.widgetWithText(TextButton, '저장'));

Future<void> _tapInForm(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 입력 화면의 종류 칩을 누른다.
Future<void> _chooseKind(WidgetTester tester, String kind) =>
    _tapInForm(tester, _inForm(find.widgetWithText(ChoiceChip, kind)));

/// 입력 화면의 일차를 고른다.
Future<void> _chooseDay(WidgetTester tester, String day) async {
  await _tapInForm(
    tester,
    _inForm(find.widgetWithText(DropdownButtonFormField<int>, '일차')),
  );
  await tester.tap(find.text(day).last);
  await tester.pumpAndSettle();
}

Finder get _slotField =>
    _inForm(find.widgetWithText(DropdownButtonFormField<int>, '넣을 자리'));

/// 입력 화면의 넣을 자리를 고른다.
Future<void> _chooseSlot(WidgetTester tester, String slot) async {
  await _tapInForm(tester, _slotField);
  await tester.tap(find.text(slot).last);
  await tester.pumpAndSettle();
}

/// 넣을 자리 칸이 고르고 있는 일차 안 순서.
int? _slotOrder(WidgetTester tester) => tester
    .widget<DropdownButton<int>>(
      find.descendant(
        of: _slotField,
        matching: find.byType(DropdownButton<int>),
      ),
    )
    .value;

/// 넣을 자리 칸에 [slot] 선택지가 있는지. 칸은 모든 선택지를 그려 두고 고른 것만 보여 준다.
Finder _slotOption(String slot) =>
    find.descendant(of: _slotField, matching: find.text(slot));

/// 임시 핀을 꽂고 입력 화면을 연다.
Future<void> _openAddForm(WidgetTester tester) async {
  await tapMap(tester, _somewhere);
  await tester.tap(find.widgetWithText(FilledButton, '추가'));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_saveButton);
  await tester.pumpAndSettle();
}

ItineraryStopTile _tile(WidgetTester tester, String name) =>
    tester.widget<ItineraryStopTile>(
      find.byWidgetPredicate(
        (w) => w is ItineraryStopTile && w.stop.name == name,
      ),
    );

/// 시트의 장소 줄 이름. 위에서부터다. 시트 밖으로 넘어간 줄도 센다.
List<String> _tileNames(WidgetTester tester) => [
  for (final tile in tester.widgetList<ItineraryStopTile>(
    find.byType(ItineraryStopTile, skipOffstage: false),
  ))
    tile.stop.name,
];

void main() {
  group('pin', () {
    testWidgets('drops where the map is tapped and moves with the next tap', (
      tester,
    ) async {
      await _pumpJeju(tester);

      await tapMap(tester, _somewhere);

      expect(_draft(tester)?.position, _somewhere);
      expect(find.text('여기에 장소 추가'), findsOneWidget);
      // 카메라는 장소에만 맞춘다.
      expect(
        mapScene(tester).camera.bounds,
        cameraBoundsFor(_stops.map((s) => s.position)),
      );

      await tapMap(tester, _elsewhere);

      expect(_draft(tester)?.position, _elsewhere);

      await tester.tap(find.byTooltip('취소'));
      await tester.pumpAndSettle();

      expect(_draft(tester), isNull);
      expect(find.text('여기에 장소 추가'), findsNothing);
    });

    testWidgets('names itself after a place written on the map', (
      tester,
    ) async {
      await _pumpJeju(tester);

      await tapMap(tester, _somewhere, placeName: '성산일출봉');

      expect(_draft(tester)?.caption, '성산일출봉');
      expect(find.text('‘성산일출봉’ 추가'), findsOneWidget);
    });

    testWidgets('waits for the sheet to fold first in a day view', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      await tapMap(tester, _somewhere);

      // 첫 탭은 시트만 접는다.
      expect(_draft(tester), isNull);
      expect(mapScene(tester).logoLift, 0);

      await tapMap(tester, _somewhere);

      expect(_draft(tester)?.position, _somewhere);
    });

    testWidgets('drops on the first tap whenever the sheet is folded', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');

      Future<void> expectPinAfterFolding() async {
        // 시트가 올라와 있으면 첫 탭은 접기만 한다.
        await tapMap(tester, _somewhere);
        expect(_draft(tester), isNull);
        expect(mapScene(tester).logoLift, 0);
        // 접힌 뒤에는 첫 탭에 핀이 꽂힌다.
        await tapMap(tester, _somewhere);
        expect(_draft(tester), isNotNull);
        await tester.tap(find.byTooltip('취소'));
        await tester.pumpAndSettle();
      }

      // 끝까지 펼쳤다가 접기, 가운데 높이(지도에서 장소를 누름)에서 접기를 되풀이한다.
      for (var round = 0; round < 3; round++) {
        await _openSheet(tester);
        await expectPinAfterFolding();
        await tapMarker(tester, 'c');
        expect(mapScene(tester).logoLift, greaterThan(0));
        await expectPinAfterFolding();
      }

      // 손잡이를 끌어 내려 접은 뒤에도 같다.
      await _openSheet(tester);
      await tester.drag(find.text('장소 3곳'), const Offset(0, 1600));
      await tester.pumpAndSettle();
      expect(mapScene(tester).logoLift, 0);

      await tapMap(tester, _somewhere);

      expect(_draft(tester), isNotNull);
    });

    testWidgets('goes away when the view changes', (tester) async {
      await _pumpJeju(tester);
      await tapMap(tester, _somewhere);

      await _tapChip(tester, '1일차');

      expect(_draft(tester), isNull);
    });
  });

  group('adding', () {
    testWidgets('adds a named place to the last day, before its lodging', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await tapMap(tester, _somewhere, placeName: '성산일출봉');

      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('장소 추가'), findsOneWidget);
      expect(tester.widget<TextField>(_nameField).controller!.text, '성산일출봉');

      await _save(tester);

      expect(_form, findsNothing);
      expect(_draft(tester), isNull);
      // 전체 보기라 마지막으로 채우던 2일차에, 그날 밤 숙소 앞에 들어간다.
      final scene = mapScene(tester);
      final added = scene.markers.singleWhere((m) => m.caption == '성산일출봉');
      expect(added.position, _somewhere);
      expect(added.look.label, '3');
      expect(added.look.fill, scene.markers[3].look.fill, reason: '2일차 색');
    });

    testWidgets('adds to the day being viewed and shows it in the sheet', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '1일차');
      await tapMap(tester, _somewhere);
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      await tester.enterText(_nameField, '  돌하르방 카페 ');
      await _chooseKind(tester, '음식');
      await _save(tester);

      expect(_tileNames(tester), ['a', 'b', '돌하르방 카페', 'hotel']);
      expect(_tile(tester, '돌하르방 카페').highlighted, isTrue);
      expect(_tile(tester, '돌하르방 카페').stop.kind, StopKind.food);
      expect(find.text('음식'), findsWidgets);
    });

    testWidgets('says where it went when added to another day', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '1일차');
      await tapMap(tester, _somewhere);
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      await tester.enterText(_nameField, '오름');
      await _chooseDay(tester, '3일차');
      await _save(tester);

      expect(find.text('3일차에 넣었습니다.'), findsOneWidget);
      expect(_tileNames(tester), ['a', 'b', 'hotel']);
    });

    testWidgets('cannot be saved without a name', (tester) async {
      await _pumpJeju(tester);
      await tapMap(tester, _somewhere);
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextButton>(_saveButton).onPressed, isNull);

      await tester.enterText(_nameField, '   ');
      await tester.pump();

      expect(tester.widget<TextButton>(_saveButton).onPressed, isNull);
    });

    testWidgets('asks before throwing away what was written', (tester) async {
      await _pumpJeju(tester);
      await tapMap(tester, _somewhere);
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();
      await tester.enterText(_nameField, '오름');
      // 고친 것을 화면이 알게 한 프레임 그린다.
      await tester.pump();

      await tester.tap(_inForm(find.byTooltip('닫기')));
      await tester.pumpAndSettle();

      expect(find.text('고친 내용을 버릴까요?'), findsOneWidget);

      await tester.tap(find.text('취소').last);
      await tester.pumpAndSettle();

      expect(_form, findsOneWidget);

      await tester.tap(_inForm(find.byTooltip('닫기')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('버리기'));
      await tester.pumpAndSettle();

      expect(_form, findsNothing);
      expect(mapScene(tester).captions, isNot(contains('오름')));
      // 핀은 남아서 다시 추가할 수 있다.
      expect(_draft(tester), isNotNull);
    });

    testWidgets('closes right away when nothing was written', (tester) async {
      await _pumpJeju(tester);
      await tapMap(tester, _somewhere, placeName: '성산일출봉');
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      await tester.tap(_inForm(find.byTooltip('닫기')));
      await tester.pumpAndSettle();

      expect(find.text('고친 내용을 버릴까요?'), findsNothing);
      expect(_form, findsNothing);
    });
  });

  group('choosing where a new stop goes', () {
    const preview = '이 자리에 넣으면 아래 이동 수단이 지워집니다.';

    testWidgets('starts before the lodging of the night', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '1일차');
      await _openAddForm(tester);

      expect(_slotOrder(tester), 2);
      expect(_slotOption('‘hotel’ 앞 (기본)'), findsOneWidget);
      expect(_inForm(find.text(preview)), findsNothing);

      await _tapInForm(tester, _slotField);

      // 펼친 선택지는 맨 앞부터 그날 밤 숙소 앞까지다. 숙소 뒤에 넣으면 다음 날이 숙소에서 출발하지 않아서 없다.
      // b 뒤와 숙소 앞은 같은 자리라 숙소 앞으로만 쓴다.
      final options = [
        for (final item in tester.widgetList<DropdownMenuItem<int>>(
          find.descendant(
            of: find.byType(Scrollable).last,
            matching: find.byType(DropdownMenuItem<int>),
          ),
        ))
          (item.child as Text).data,
      ];
      expect(options, ['‘a’ 앞', '‘a’ 뒤', '‘hotel’ 앞 (기본)']);
    });

    testWidgets('puts the stop where it is chosen', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '1일차');
      await _openAddForm(tester);

      await tester.enterText(_nameField, '오름');
      await _chooseSlot(tester, '‘a’ 앞');
      await _save(tester);

      expect(_tileNames(tester), ['오름', 'a', 'b', 'hotel']);
    });

    testWidgets('shows the transport the slot would drop', (tester) async {
      await _pumpJeju(tester, legs: {('b', 'hotel'): _walk});
      await _tapChip(tester, '1일차');
      await _openAddForm(tester);

      expect(_inForm(find.text(preview)), findsOneWidget);
      expect(_inForm(find.text('1일차 b → hotel')), findsOneWidget);
      expect(_inForm(find.text('도보')), findsOneWidget);

      await _chooseSlot(tester, '‘a’ 뒤');

      expect(_inForm(find.text(preview)), findsNothing);
    });

    testWidgets('drops the shown transport without asking again', (
      tester,
    ) async {
      final container = await _pumpJeju(
        tester,
        legs: {('a', 'b'): _subway, ('b', 'hotel'): _walk},
      );
      await _tapChip(tester, '1일차');
      await _openAddForm(tester);
      await tester.enterText(_nameField, '오름');
      await tester.pump();

      await _save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(_tileNames(tester), ['a', 'b', '오름', 'hotel']);
      final segments = _savedSegments(container);
      expect(_segmentOf(segments, 'a', 'b').legs, _subway);
      expect(segments.where((s) => s.fromStopId == 'b').single.legs, isEmpty);
    });

    testWidgets('follows the kind until a slot is chosen', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '1일차');
      await _openAddForm(tester);

      await _chooseKind(tester, '숙소');

      // 숙소는 맨 뒤가 기본이다.
      expect(_slotOrder(tester), 3);
      expect(_slotOption('‘hotel’ 뒤 (기본)'), findsOneWidget);

      await _chooseSlot(tester, '‘a’ 뒤');
      await _chooseKind(tester, '음식');

      expect(_slotOrder(tester), 1);
    });

    testWidgets('leaves the lodging of the night last for other kinds', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '1일차');
      await _openAddForm(tester);
      await tester.enterText(_nameField, '새 숙소');
      await _chooseKind(tester, '숙소');
      await _chooseSlot(tester, '‘hotel’ 뒤 (기본)');

      // 숙소 뒤는 숙소만 고를 수 있다. 종류를 바꾸면 기본 자리로 돌아간다.
      await _chooseKind(tester, '음식');

      expect(_slotOrder(tester), 2);

      await _save(tester);

      expect(_tileNames(tester), ['a', 'b', '새 숙소', 'hotel']);
    });

    testWidgets('goes back to the default slot on another day', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '1일차');
      await _openAddForm(tester);
      await _chooseSlot(tester, '‘a’ 앞');

      await _chooseDay(tester, '2일차');

      expect(_slotOrder(tester), 2);
      expect(_slotOption('‘hotel2’ 앞 (기본)'), findsOneWidget);

      await _chooseDay(tester, '3일차');

      // 장소가 없는 일차는 자리가 하나뿐이라 고를 수 없다.
      expect(_slotOption('첫 장소'), findsWidgets);
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.descendant(
                of: _slotField,
                matching: find.byType(DropdownButton<int>),
              ),
            )
            .onChanged,
        isNull,
      );
    });
  });

  group('editing', () {
    /// 목록에서 장소 줄을 누르고, 그 줄에 뜬 연필 아이콘을 누른다.
    Future<void> openEditor(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('장소 편집'));
      await tester.pumpAndSettle();
    }

    testWidgets('changes the name and kind but keeps notes', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);
      await openEditor(tester, 'c');

      expect(find.text('장소 편집'), findsOneWidget);
      expect(_inForm(find.text('주차 2시간 무료')), findsOneWidget);

      await tester.enterText(_nameField, '용머리해안');
      await _chooseKind(tester, '관광');
      await _save(tester);

      expect(_tileNames(tester), ['hotel', '용머리해안', 'd', 'hotel2']);
      final edited = _tile(tester, '용머리해안').stop;
      expect(edited.kind, StopKind.tour);
      expect(edited.memo, '주차 2시간 무료');
      expect(mapScene(tester).captions, contains('용머리해안'));
    });

    testWidgets('clears the planned time', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);
      expect(find.text('관광 · 오후 2:30'), findsOneWidget);
      await openEditor(tester, 'd');

      expect(_inForm(find.text('오후 2:30')), findsOneWidget);

      await _tapInForm(tester, _inForm(find.byTooltip('예정 시각 지우기')));

      expect(_inForm(find.text('정하지 않음')), findsOneWidget);

      await _save(tester);

      expect(_tile(tester, 'd').stop.plannedTime, isNull);
      expect(find.text('관광 · 오후 2:30'), findsNothing);
    });

    testWidgets('moves a stop to another day, before its lodging', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);
      await openEditor(tester, 'c');

      await _chooseDay(tester, '1일차');
      await _save(tester);

      expect(find.text('1일차로 옮겼습니다.'), findsOneWidget);
      expect(_tileNames(tester), ['hotel', 'd', 'hotel2']);

      await _tapChip(tester, '1일차');
      await _openSheet(tester);

      expect(_tileNames(tester), ['a', 'b', 'c', 'hotel']);
    });

    testWidgets('chooses the slot only when moving to another day', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);
      await openEditor(tester, 'c');

      expect(_slotField, findsNothing);

      await _chooseDay(tester, '1일차');

      expect(_slotOrder(tester), 2);
      expect(_slotOption('‘hotel’ 앞 (기본)'), findsOneWidget);

      await _chooseSlot(tester, '‘a’ 뒤');
      await _save(tester);

      await _tapChip(tester, '1일차');
      await _openSheet(tester);

      expect(_tileNames(tester), ['a', 'c', 'b', 'hotel']);
    });

    testWidgets('does nothing when saved without changes', (tester) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '2일차');
      await _openSheet(tester);
      await openEditor(tester, 'c');

      await _save(tester);

      expect(_tileNames(tester), ['hotel', 'c', 'd', 'hotel2']);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('starting where the day before ended', () {
    /// 1일차: a > 공항(야간 비행기를 탄다), 2일차: q > r. 공항 → q는 비행기다.
    final stops = [
      testStop('a', tripId: 'jeju'),
      testStop('airport', tripId: 'jeju', order: 1),
      testStop('q', tripId: 'jeju', day: 2),
      testStop('r', tripId: 'jeju', day: 2, order: 1),
    ];
    const flight = [TransportLeg(TransportMode.flight)];

    testWidgets('starts from a last place that is not lodging', (tester) async {
      await _pumpJeju(tester, stops: stops, legs: {('airport', 'q'): flight});
      await _tapChip(tester, '2일차');
      await _openSheet(tester);

      expect(_tileNames(tester), ['airport', 'q', 'r']);
      expect(find.text('전날 마지막 장소에서 출발'), findsOneWidget);
      expect(find.text('전날 묵은 숙소에서 출발'), findsNothing);
      // 일차를 넘는 구간이 목록과 지도에 보인다.
      expect(
        find.descendant(
          of: find.byType(ItinerarySegmentTile),
          matching: find.text('비행기'),
        ),
        findsOneWidget,
      );
      expect(mapScene(tester).captions, ['airport', 'q', 'r']);
      // 출발 장소가 숙소가 아니라 연박 버튼은 없다.
      expect(find.textContaining('에서 묵기'), findsNothing);
    });

    testWidgets('shows the segment across days tapped on the whole map', (
      tester,
    ) async {
      final container = await _pumpJeju(tester, stops: stops);
      final across = _segmentOf(_savedSegments(container), 'airport', 'q');

      await tapLine(tester, across.id);

      // 도착 장소의 일차(2일차) 목록에서 그 구간 줄을 보여 준다.
      expect(mapScene(tester).captions, ['airport', 'q', 'r']);
      final highlighted = tester
          .widgetList<ItinerarySegmentTile>(
            find.byType(ItinerarySegmentTile, skipOffstage: false),
          )
          .where((tile) => tile.highlighted);
      expect(highlighted, hasLength(1));
    });
  });

  group('staying another night', () {
    testWidgets('puts the lodging of the night before at the end of the day', (
      tester,
    ) async {
      await _pumpJeju(tester);
      await _tapChip(tester, '3일차');
      await _openSheet(tester);

      expect(_tileNames(tester), ['hotel2']);

      await tester.tap(find.text('오늘 밤도 ‘hotel2’에서 묵기'));
      await tester.pumpAndSettle();

      // 그날 첫 장소가 전날과 같은 숙소면 출발 숙소 줄은 따로 보이지 않는다(같은 숙소가 두 번 보이지 않게).
      // 지도에도 마커 하나다.
      expect(_tileNames(tester), ['hotel2']);
      expect(find.text('전날 묵은 숙소에서 출발'), findsNothing);
      final tonight = tester
          .widgetList<ItineraryStopTile>(
            find.byType(ItineraryStopTile, skipOffstage: false),
          )
          .last;
      expect(tonight.stop.day, 3);
      expect(tonight.highlighted, isTrue);
      expect(mapScene(tester).captions, ['hotel2']);
      // 그날 밤 숙소가 생겨서 버튼은 사라진다.
      expect(find.textContaining('오늘 밤도'), findsNothing);
    });

    group('across a written transport', () {
      /// 1일차: a > 숙소, 2일차: c, 3일차: e. c → e는 지하철이다.
      final stops = [
        testStop('a', tripId: 'jeju'),
        testLodging('hotel', tripId: 'jeju', order: 1),
        testStop('c', tripId: 'jeju', day: 2),
        testStop('e', tripId: 'jeju', day: 3),
      ];

      Future<ProviderContainer> stayOnDay2(WidgetTester tester) async {
        final container = await _pumpJeju(
          tester,
          stops: stops,
          legs: {('c', 'e'): _subway},
        );
        await _tapChip(tester, '2일차');
        await _openSheet(tester);
        await tester.tap(find.text('오늘 밤도 ‘hotel’에서 묵기'));
        await tester.pumpAndSettle();
        return container;
      }

      testWidgets('asks before dropping it', (tester) async {
        await stayOnDay2(tester);

        expect(find.text('이동 수단이 사라집니다'), findsOneWidget);
        expect(
          find.text('‘hotel’에서 묵으면 아래 구간의 이동 수단이 지워집니다. 넣을까요?'),
          findsOneWidget,
        );
        expect(find.text('2일차 c → 3일차 e'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('지하철 2정류장'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('leaves the day as it was when cancelled', (tester) async {
        final container = await stayOnDay2(tester);

        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();

        expect(_tileNames(tester), ['hotel', 'c']);
        expect(_segmentOf(_savedSegments(container), 'c', 'e').legs, _subway);
      });

      testWidgets('stays and drops it when confirmed', (tester) async {
        final container = await stayOnDay2(tester);

        await tester.tap(find.text('넣기'));
        await tester.pumpAndSettle();

        expect(_tileNames(tester), ['hotel', 'c', 'hotel']);
        expect(_savedSegments(container).every((s) => s.legs.isEmpty), isTrue);
      });
    });

    group('at a lodging visited that day', () {
      /// 1일차: a > 숙소, 2일차: q > 숙소B(체크인) > r, 3일차: e.
      final stops = [
        testStop('a', tripId: 'jeju'),
        testLodging('hotel', tripId: 'jeju', order: 1),
        testStop('q', tripId: 'jeju', day: 2),
        testStop('B', tripId: 'jeju', day: 2, order: 1, kind: StopKind.lodging),
        testStop('r', tripId: 'jeju', day: 2, order: 2),
        testStop('e', tripId: 'jeju', day: 3),
      ];
      const tonightAtB = '오늘 밤은 ‘B’에서 묵기';
      const againAtHotel = '오늘 밤도 ‘hotel’에서 묵기';

      testWidgets('offers it before the lodging of the night before', (
        tester,
      ) async {
        await _pumpJeju(tester, stops: stops);
        await _tapChip(tester, '2일차');
        await _openSheet(tester);

        expect(find.text(tonightAtB), findsOneWidget);
        expect(find.text(againAtHotel), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(tonightAtB)).dy,
          lessThan(tester.getTopLeft(find.text(againAtHotel)).dy),
        );
      });

      testWidgets('ends the day there and starts the next day from it', (
        tester,
      ) async {
        await _pumpJeju(tester, stops: stops);
        await _tapChip(tester, '2일차');
        await _openSheet(tester);

        await tester.tap(find.text(tonightAtB));
        await tester.pumpAndSettle();

        expect(_tileNames(tester), ['hotel', 'q', 'B', 'r', 'B']);
        expect(find.textContaining('에서 묵기'), findsNothing);

        await _tapChip(tester, '3일차');
        await _openSheet(tester);

        expect(_tileNames(tester), ['B', 'e']);
      });
    });

    testWidgets('is offered only when the night has no lodging yet', (
      tester,
    ) async {
      await _pumpJeju(tester);

      // 1일차: 전날 숙소가 없다.
      await _tapChip(tester, '1일차');
      expect(find.textContaining('오늘 밤도'), findsNothing);

      // 2일차: 그날 밤 숙소(hotel2)가 이미 있다.
      await _tapChip(tester, '2일차');
      expect(find.textContaining('오늘 밤도'), findsNothing);
    });
  });
}

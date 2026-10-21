import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/route_scene.dart';
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

Future<void> _pumpJeju(WidgetTester tester) async {
  // 입력 화면과 펼친 시트가 모두 보이게 화면을 키운다.
  tester.view.physicalSize =
      const Size(800, 1800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await pumpTestApp(
    tester,
    repository: testRepository([
      testTrip(id: 'jeju', region: '제주', nights: 2),
    ], _stops),
    location: Routes.trip('jeju'),
  );
}

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
  await _tapInForm(tester, _inForm(find.byType(DropdownButtonFormField<int>)));
  await tester.tap(find.text(day).last);
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

  group('editing', () {
    Future<void> openEditor(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '편집'));
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

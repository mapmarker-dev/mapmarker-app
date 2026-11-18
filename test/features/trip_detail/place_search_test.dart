import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/data/addresses/address_api.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/sample/jeju_sample.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/candidate_form_dialog.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/place_finder_dialog.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/stop_form_dialog.dart';

import '../../helpers/fake_address_api.dart';
import '../../helpers/memory_sample_store.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 2박 3일 여행. 1일차: a > b > hotel, 2일차: c > d > hotel2.
final _stops = [
  testStop('a', tripId: 'jeju', kind: StopKind.tour),
  testStop('b', tripId: 'jeju', order: 1),
  testLodging('hotel', tripId: 'jeju', order: 2),
  testStop('c', tripId: 'jeju', day: 2),
  testStop('d', tripId: 'jeju', day: 2, order: 1),
  testLodging('hotel2', tripId: 'jeju', day: 2, order: 2),
];

/// 후보 하나. 동선보다 멀리 있다.
const _udo = Candidate(
  id: 'udo',
  tripId: 'jeju',
  latitude: 33.5,
  longitude: 126.95,
  name: '우도',
  address: '제주 우도면',
);

const _found = LatLng(33.45, 126.56);

late FakeAddressApi _api;

Future<ProviderContainer> _pump(WidgetTester tester) {
  _api = FakeAddressApi(
    result: AddressSearchResult(
      detail: '1층',
      addresses: [testAddress(road: '제주특별자치도 제주시 관덕로 1', extra: null)],
    ),
    position: _found,
  );
  return pumpTestApp(
    tester,
    repository: testRepository(
      [testTrip(id: 'jeju', region: '제주', nights: 2)],
      _stops,
      [_udo],
    ),
    location: Routes.trip('jeju'),
    addressApi: _api,
  );
}

TripRoute _route(ProviderContainer container) =>
    container.read(tripRouteProvider('jeju')).value!;

List<String> _dayNames(ProviderContainer container, int day) => [
  for (final stop in _route(container).stops)
    if (stop.day == day) stop.name,
];

Finder get _plus => find.byTooltip('여기에 장소 넣기');

/// 찾기 화면에서 주소를 찾아 첫 결과를 고른다.
Future<void> _findAndPick(WidgetTester tester) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(PlaceFinderDialog),
      matching: find.byType(TextField),
    ),
    '관덕로 1 1층',
  );
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, '제주특별자치도 제주시 관덕로 1'));
  await tester.pumpAndSettle();
}

Finder _inDialog(Type type, Finder finder) =>
    find.descendant(of: find.byType(type), matching: finder);

/// 입력 화면의 [label] 칸. 아래 버튼까지 넘긴 뒤에도 읽게 화면 밖 칸도 찾는다.
TextField _field(WidgetTester tester, Type form, String label) =>
    tester.widget<TextField>(
      find.descendant(
        of: find.byType(form),
        matching: find.widgetWithText(TextField, label, skipOffstage: false),
        skipOffstage: false,
      ),
    );

Future<void> _nameAndSave(WidgetTester tester, Type form, String name) async {
  await tester.enterText(
    _inDialog(form, find.widgetWithText(TextField, '이름')),
    name,
  );
  await tester.pump();
  await tester.tap(_inDialog(form, find.text('저장')));
  await tester.pumpAndSettle();
}

void main() {
  group('plus between stops', () {
    testWidgets('opens the finder titled with the two places and adds there', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tapChip(tester, '2일차');

      // 출발(hotel)→c, c→d, d→hotel2 구간마다 ⊕가 있다.
      expect(_plus, findsNWidgets(3));
      await tester.tap(_plus.at(1));
      await tester.pumpAndSettle();

      expect(find.text('2일차 c → d 사이에 넣기'), findsOneWidget);
      await _findAndPick(tester);

      // 주소가 채워지고 이름은 비어 있다(가게 이름은 사용자가 쓴다).
      // 넣을 자리 칸은 없고, 넣을 곳은 제목으로 보인다.
      expect(find.byType(StopFormDialog), findsOneWidget);
      expect(_field(tester, StopFormDialog, '이름').controller!.text, '');
      expect(
        _field(tester, StopFormDialog, '주소').controller!.text,
        '제주특별자치도 제주시 관덕로 1, 1층',
      );
      expect(
        _inDialog(StopFormDialog, find.text('2일차 c → d 사이에 넣기')),
        findsOneWidget,
      );

      await _nameAndSave(tester, StopFormDialog, '카페');

      expect(_dayNames(container, 2), ['c', '카페', 'd', 'hotel2']);
      final added = _route(container).stops.singleWhere((s) => s.name == '카페');
      expect(added.address, '제주특별자치도 제주시 관덕로 1, 1층');
      expect(added.position, _found);
    });

    testWidgets('goes to the default place when the day is changed', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tapChip(tester, '2일차');
      await tester.tap(_plus.at(1));
      await tester.pumpAndSettle();
      await _findAndPick(tester);
      await tester.enterText(
        _inDialog(StopFormDialog, find.widgetWithText(TextField, '이름')),
        '카페',
      );
      await tester.pump();

      final dayField = _inDialog(
        StopFormDialog,
        find.widgetWithText(DropdownButtonFormField<int>, '일차'),
      );
      await tester.ensureVisible(dayField);
      await tester.pumpAndSettle();
      await tester.tap(dayField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1일차').last);
      await tester.pumpAndSettle();

      // ⊕ 자리는 2일차의 자리라 1일차에서는 기본 자리(숙소 앞)다.
      expect(find.text('2일차 c → d 사이에 넣기'), findsNothing);
      expect(_inDialog(StopFormDialog, find.text('장소 추가')), findsOneWidget);
      await tester.tap(_inDialog(StopFormDialog, find.text('저장')));
      await tester.pumpAndSettle();

      expect(_dayNames(container, 1), ['a', 'b', '카페', 'hotel']);
    });

    testWidgets('puts the place first when tapped after the start', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tapChip(tester, '2일차');

      await tester.tap(_plus.first);
      await tester.pumpAndSettle();

      expect(find.text('2일차 hotel → c 사이에 넣기'), findsOneWidget);
      await _findAndPick(tester);
      await _nameAndSave(tester, StopFormDialog, '카페');

      expect(_dayNames(container, 2), ['카페', 'c', 'd', 'hotel2']);
    });

    testWidgets('stays apart from the transport row when it is picked', (
      tester,
    ) async {
      await _pump(tester);
      await tapChip(tester, '2일차');

      // c→d 구간 줄을 눌러 고른다.
      await tester.tap(find.text('이동 수단 미정').at(1));
      await tester.pumpAndSettle();

      final segment = find.ancestor(
        of: find.text('이동 수단 미정').at(1),
        matching: find.byType(ItinerarySegmentTile),
      );
      expect(tester.widget<ItinerarySegmentTile>(segment).highlighted, isTrue);
      // 구간 줄의 바탕(고르면 색이 바뀌는 Material)은 ⊕를 품지 않는다.
      final background = find
          .descendant(of: segment, matching: find.byType(Material))
          .first;
      expect(find.descendant(of: background, matching: _plus), findsNothing);
      expect(find.descendant(of: segment, matching: _plus), findsOneWidget);
      // ⊕는 구간 줄 바로 위에 있다.
      expect(
        tester.getBottomLeft(find.descendant(of: segment, matching: _plus)).dy,
        lessThanOrEqualTo(tester.getTopLeft(background).dy),
      );
    });

    testWidgets('the add row puts it in the default slot', (tester) async {
      final container = await _pump(tester);
      await tapChip(tester, '2일차');

      // 목록 끝이라 넘겨야 보인다.
      await tester.ensureVisible(find.text('장소 넣기', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('장소 넣기'));
      await tester.pumpAndSettle();

      expect(find.text('2일차에 장소 넣기'), findsOneWidget);
      await _findAndPick(tester);
      await _nameAndSave(tester, StopFormDialog, '카페');

      // 그날 밤 숙소 앞이다.
      expect(_dayNames(container, 2), ['c', 'd', '카페', 'hotel2']);
    });

    testWidgets('the add row works on a day without places', (tester) async {
      final container = await _pump(tester);
      await tapChip(tester, '3일차');

      // 목록 끝이라 넘겨야 보인다.
      await tester.ensureVisible(find.text('장소 넣기', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('장소 넣기'));
      await tester.pumpAndSettle();
      await _findAndPick(tester);
      await _nameAndSave(tester, StopFormDialog, '공항');

      expect(_dayNames(container, 3), ['공항']);
    });

    testWidgets('adds nothing when the stop form is closed', (tester) async {
      final container = await _pump(tester);
      await tapChip(tester, '2일차');
      await tester.tap(_plus.at(1));
      await tester.pumpAndSettle();
      await _findAndPick(tester);

      await tester.tap(_inDialog(StopFormDialog, find.byTooltip('닫기')));
      await tester.pumpAndSettle();

      expect(find.byType(StopFormDialog), findsNothing);
      expect(find.byType(PlaceFinderDialog), findsNothing);
      expect(_dayNames(container, 2), ['c', 'd', 'hotel2']);
    });

    testWidgets(
      'hides the plus but keeps the add row while lodging is hidden',
      (tester) async {
        await _pump(tester);
        await tapChip(tester, '2일차');

        await tester.tap(find.widgetWithText(FilterChip, '숙소'));
        await tester.pumpAndSettle();

        expect(_plus, findsNothing);
        expect(find.text('장소 넣기'), findsOneWidget);
      },
    );

    testWidgets('is not offered on the sample trip', (tester) async {
      await pumpTestApp(
        tester,
        repository: withSample(testRepository([]), MemorySampleStore()),
        location: Routes.trip(sampleTripId),
      );
      await tapChip(tester, '1일차');

      expect(_plus, findsNothing);
      expect(find.text('장소 넣기'), findsNothing);

      await tapChip(tester, '후보 목록');
      expect(find.text('후보 찾아 넣기'), findsNothing);
    });
  });

  group('add row in the candidate list', () {
    testWidgets('saves a candidate found by address with the typed name', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tapChip(tester, '후보 목록');

      await tester.tap(find.text('후보 찾아 넣기'));
      await tester.pumpAndSettle();

      expect(find.text('후보로 저장할 곳 찾기'), findsOneWidget);
      await _findAndPick(tester);

      // 이름은 비어 있고 사용자가 쓴다.
      expect(find.byType(CandidateFormDialog), findsOneWidget);
      expect(_field(tester, CandidateFormDialog, '이름').controller!.text, '');
      await _nameAndSave(tester, CandidateFormDialog, '동문시장');

      final saved = _route(container).candidates.last;
      expect(saved.name, '동문시장');
      expect(saved.address, '제주특별자치도 제주시 관덕로 1, 1층');
      expect(saved.position, _found);
      // 동선은 그대로다.
      expect(_route(container).stops, hasLength(_stops.length));
    });
  });

  group('finding the place again in the address field', () {
    /// 입력 화면의 주소 칸에 새 주소를 쓰고 돋보기로 찾아 첫 결과를 고른다.
    Future<void> relocate(WidgetTester tester, Type form) async {
      final field = _inDialog(form, find.widgetWithText(TextField, '주소'));
      await tester.enterText(field, '관덕로 1 1층');
      await tester.pump();
      await tester.tap(_inDialog(form, find.byTooltip('찾기')));
      await tester.pumpAndSettle();
      final row = _inDialog(
        form,
        find.widgetWithText(ListTile, '제주특별자치도 제주시 관덕로 1'),
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('has no separate page or button for it', (tester) async {
      await _pump(tester);
      await tapChip(tester, '2일차');
      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('장소 편집'));
      await tester.pumpAndSettle();

      expect(find.text('주소로 위치 다시 찾기'), findsNothing);
      expect(_inDialog(StopFormDialog, find.byTooltip('찾기')), findsOneWidget);
    });

    testWidgets('moves a stop with its new address when saved', (tester) async {
      final container = await _pump(tester);
      await tapChip(tester, '2일차');
      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('장소 편집'));
      await tester.pumpAndSettle();

      await relocate(tester, StopFormDialog);

      expect(
        _field(tester, StopFormDialog, '주소').controller!.text,
        '제주특별자치도 제주시 관덕로 1, 1층',
      );
      // 저장하기 전에는 그대로다.
      final before = _route(container).stopById('c')!;
      expect(before.position, isNot(_found));

      await tester.tap(_inDialog(StopFormDialog, find.text('저장')));
      await tester.pumpAndSettle();

      final moved = _route(container).stopById('c')!;
      expect(moved.position, _found);
      expect(moved.address, '제주특별자치도 제주시 관덕로 1, 1층');
      expect((moved.day, moved.order), (before.day, before.order));
    });

    testWidgets('leaves the stop where it was when the form is closed', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tapChip(tester, '2일차');
      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('장소 편집'));
      await tester.pumpAndSettle();
      final before = _route(container).stopById('c')!;

      await relocate(tester, StopFormDialog);
      await tester.tap(_inDialog(StopFormDialog, find.byTooltip('닫기')));
      await tester.pumpAndSettle();
      // 고친 것이 있어서 버릴지 묻는다.
      await tester.tap(find.text('버리기'));
      await tester.pumpAndSettle();

      expect(_route(container).stopById('c')!.position, before.position);
      expect(_route(container).stopById('c')!.address, before.address);
    });

    testWidgets('clears the address with x but keeps the place', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tapChip(tester, '후보 목록');
      await tester.tap(find.text('우도'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('후보 고치기'));
      await tester.pumpAndSettle();
      final before = _route(container).candidateById('udo')!;

      await tester.tap(
        _inDialog(CandidateFormDialog, find.byTooltip('주소 지우기')),
      );
      await tester.pumpAndSettle();
      expect(_field(tester, CandidateFormDialog, '주소').controller!.text, '');
      await tester.tap(_inDialog(CandidateFormDialog, find.text('저장')));
      await tester.pumpAndSettle();

      final saved = _route(container).candidateById('udo')!;
      expect(saved.address, isEmpty);
      expect(saved.position, before.position);
    });

    testWidgets('moves a candidate with its new address when saved', (
      tester,
    ) async {
      final container = await _pump(tester);
      await tapChip(tester, '후보 목록');
      await tester.tap(find.text('우도'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('후보 고치기'));
      await tester.pumpAndSettle();

      await relocate(tester, CandidateFormDialog);
      await tester.tap(_inDialog(CandidateFormDialog, find.text('저장')));
      await tester.pumpAndSettle();

      final moved = _route(container).candidateById('udo')!;
      expect(moved.position, _found);
      expect(moved.address, '제주특별자치도 제주시 관덕로 1, 1층');
      expect(moved.name, '우도');
    });

    testWidgets('is not offered when a candidate goes into the route', (
      tester,
    ) async {
      await _pump(tester);
      await tapChip(tester, '후보 목록');
      await tester.tap(find.text('우도'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('동선에 넣기'));
      await tester.pumpAndSettle();

      expect(find.byType(StopFormDialog), findsOneWidget);
      // 후보 위치 그대로 넣어서 주소 칸은 고칠 수 없고, 그 까닭과 바꾸는 곳을 알린다.
      expect(_inDialog(StopFormDialog, find.byTooltip('찾기')), findsNothing);
      expect(_inDialog(StopFormDialog, find.byTooltip('주소 지우기')), findsNothing);
      final address = _field(tester, StopFormDialog, '주소');
      expect(address.controller!.text, '제주 우도면');
      expect(address.enabled, isFalse);
      expect(
        _inDialog(
          StopFormDialog,
          find.text('후보의 위치 그대로 넣습니다. 위치는 넣은 뒤 장소 편집에서 바꿀 수 있습니다.'),
        ),
        findsOneWidget,
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/sample/jeju_sample.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_screen.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trips/widgets/trip_card.dart';
import 'package:mapmarker_app/features/trips/widgets/trip_phase_menu.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/memory_sample_store.dart';
import '../../helpers/test_app.dart';

const _sampleTitle = '제주 3박 4일 가을 여행';

Finder get _sampleCard =>
    find.ancestor(of: find.text(_sampleTitle), matching: find.byType(TripCard));

void main() {
  late FlakyTripRepository user;
  late MemorySampleStore store;

  setUp(() {
    user = FlakyTripRepository(testRepository([testTrip(id: 'busan')]));
    store = MemorySampleStore();
  });

  /// 넓은 화면(오른쪽 패널)으로 띄운다. 동선 목록이 지도 옆에 바로 보인다.
  Future<void> pumpApp(WidgetTester tester, {String? location}) async {
    tester.view.physicalSize =
        const Size(1280, 800) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final repository = withSample(user, store);
    addTearDown(repository.dispose);
    await pumpTestApp(tester, repository: repository, location: location);
  }

  Future<void> openDayOne(WidgetTester tester) async {
    await tester.tap(
      find.ancestor(
        of: find.text('1일차'),
        matching: find.byWidgetPredicate((w) => w is ChoiceChip),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('in the trip list', () {
    testWidgets('shows the sample after the user trips, marked as a sample', (
      tester,
    ) async {
      await pumpApp(tester);

      final cards = tester.widgetList<TripCard>(find.byType(TripCard));
      expect(cards.map((c) => c.trip.id), ['busan', sampleTripId]);
      expect(
        find.descendant(of: _sampleCard, matching: find.text('샘플')),
        findsOneWidget,
      );
      // 상태는 고를 수 없다.
      expect(
        tester
            .widget<TripPhaseMenu>(
              find.descendant(
                of: _sampleCard,
                matching: find.byType(TripPhaseMenu),
              ),
            )
            .onChanged,
        isNull,
      );
    });

    testWidgets('deletes the sample for good from its menu', (tester) async {
      await pumpApp(tester);

      await tester.tap(
        find.descendant(of: _sampleCard, matching: find.byTooltip('여행 메뉴')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('샘플 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('샘플 여행을 지울까요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '지우기'));
      await tester.pumpAndSettle();

      expect(find.text(_sampleTitle), findsNothing);
      expect(store.hidden, isTrue);
    });
  });

  group('the sample trip', () {
    testWidgets('can only be looked at', (tester) async {
      await pumpApp(tester, location: Routes.trip(sampleTripId));

      expect(find.text(testL10n.sampleBanner), findsOneWidget);
      expect(find.byTooltip('제목 바꾸기'), findsNothing);

      await openDayOne(tester);
      // 장소를 눌러도 연필·손잡이가 없다.
      await tester.tap(find.text('용두암'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('장소 편집'), findsNothing);
      expect(find.byIcon(Icons.drag_handle), findsNothing);
      // 구간을 눌러도 연필·곡선 핸들이 없다.
      await tester.tap(find.byType(ItinerarySegmentTile).first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('이동 수단 고치기'), findsNothing);
      expect(mapScene(tester).curveHandle, isNull);
      // 지도를 눌러도 장소를 넣을 핀이 꽂히지 않는다.
      await tapMap(tester, const LatLng(33.4, 126.5));
      expect(find.widgetWithText(FilledButton, '동선에 넣기'), findsNothing);
    });

    testWidgets('becomes a trip of the user with "use it"', (tester) async {
      await pumpApp(tester, location: Routes.trip(sampleTripId));

      // 복사하는 중에 저장소 스트림의 첫 값을 기다려서 실제 시간으로 돌린다.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, '실제로 사용하기'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // 복사한 내 여행으로 옮겨 가고, 이제 고칠 수 있다.
      final screen = tester.widget<TripDetailScreen>(
        find.byType(TripDetailScreen),
      );
      expect(isSampleTrip(screen.tripId), isFalse);
      expect(find.text(_sampleTitle), findsOneWidget);
      expect(find.byTooltip('제목 바꾸기'), findsOneWidget);
      expect(find.text(testL10n.sampleBanner), findsNothing);
      expect(store.hidden, isTrue);
      final (mine, route) = (await tester.runAsync(
        () async => (
          await user.watchTrips().first,
          await user.watchRoute(screen.tripId).first,
        ),
      ))!;
      expect(mine.map((t) => t.title), contains(_sampleTitle));
      expect(route.stops, hasLength(13));
    });

    testWidgets('stays a sample and says so when copying fails', (
      tester,
    ) async {
      user.failWrites = ApiFailure.network;
      await pumpApp(tester, location: Routes.trip(sampleTripId));

      await tester.tap(find.widgetWithText(FilledButton, '실제로 사용하기'));
      await tester.pumpAndSettle();

      expect(find.text(testL10n.saveFailedNetwork), findsOneWidget);
      expect(find.text(testL10n.sampleBanner), findsOneWidget);
      expect(store.hidden, isFalse);
    });
  });
}

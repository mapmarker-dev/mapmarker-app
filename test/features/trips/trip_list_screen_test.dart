import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/theme/app_tokens.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_screen.dart';
import 'package:mapmarker_app/features/trips/trip_create_screen.dart';
import 'package:mapmarker_app/features/trips/trip_list_controller.dart';
import 'package:mapmarker_app/features/trips/trip_list_screen.dart';
import 'package:mapmarker_app/features/trips/widgets/trip_card.dart';

import '../../helpers/test_app.dart';

/// 메뉴 항목. 메뉴가 열려 있으면 칩과 메뉴에 같은 글자가 있어서 메뉴 항목으로 좁힌다.
Finder _menuItem(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
);

void main() {
  testWidgets('shows a hint when there are no trips', (tester) async {
    await pumpTestApp(tester, repository: testRepository());

    expect(find.textContaining('아직 여행이 없습니다.'), findsOneWidget);
  });

  testWidgets('shows title, dates and phase of each trip', (tester) async {
    // 오늘은 2026-10-15다.
    await pumpTestApp(
      tester,
      repository: testRepository([
        testTrip(
          id: 'jeju',
          region: '제주',
          dates: TripDates(LocalDate(2026, 10, 14), LocalDate(2026, 10, 17)),
          updatedAt: DateTime.utc(2026, 10, 15),
        ),
        testTrip(
          id: 'gangneung',
          region: '강릉',
          season: Season.winter,
          updatedAt: DateTime.utc(2026, 10, 14),
        ),
        testTrip(
          id: 'busan',
          dates: TripDates(LocalDate(2026, 9, 5), LocalDate(2026, 9, 7)),
          updatedAt: DateTime.utc(2026, 10, 13),
        ),
      ]),
    );

    expect(find.text('제주 3박 4일 가을 여행'), findsOneWidget);
    expect(find.text('2026.10.14 – 10.17 · 3박 4일'), findsOneWidget);
    expect(find.text('여행 중'), findsOneWidget);

    expect(find.text('강릉 1박 2일 겨울 여행'), findsOneWidget);
    expect(find.text('날짜 미정 · 1박 2일'), findsOneWidget);
    expect(find.text('여행 전'), findsOneWidget);

    expect(find.text('부산 2박 3일 가을 여행'), findsOneWidget);
    expect(find.text('2026.09.05 – 09.07 · 2박 3일'), findsOneWidget);
    expect(find.text('여행 후'), findsOneWidget);

    // 최근에 고친 여행이 앞에 있다.
    final titles = tester
        .widgetList<TripCard>(find.byType(TripCard))
        .map((card) => card.trip.title);
    expect(titles, ['제주 3박 4일 가을 여행', '강릉 1박 2일 겨울 여행', '부산 2박 3일 가을 여행']);
  });

  testWidgets('opens trip creation from the + button', (tester) async {
    await pumpTestApp(tester, repository: testRepository());

    await tester.tap(find.byTooltip('여행 만들기'));
    await tester.pumpAndSettle();

    expect(find.byType(TripCreateScreen), findsOneWidget);
  });

  testWidgets('opens a trip when tapped and comes back', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
    );

    await tester.tap(find.text('부산 1박 2일 봄 여행'));
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailScreen), findsOneWidget);

    // 한국어 로캘이라 `pageBack()`이 찾는 'Back' 툴팁이 없다.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(TripListScreen), findsOneWidget);
  });

  testWidgets('changes the phase by hand and back to automatic', (
    tester,
  ) async {
    final container = await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
    );
    TripPhase? savedOverride() =>
        container.read(tripListProvider).value!.single.phaseOverride;

    // 기간이 없어서 자동으로 "여행 전"이다.
    await tester.tap(find.text('여행 전'));
    await tester.pumpAndSettle();
    await tester.tap(_menuItem('여행 중'));
    await tester.pumpAndSettle();

    expect(find.text('여행 중 · 직접'), findsOneWidget);
    expect(savedOverride(), TripPhase.during);

    await tester.tap(find.text('여행 중 · 직접'));
    await tester.pumpAndSettle();
    await tester.tap(_menuItem('자동으로 되돌리기 (자동: 여행 전)'));
    await tester.pumpAndSettle();

    expect(find.text('여행 전'), findsOneWidget);
    expect(savedOverride(), isNull);
  });

  testWidgets('cannot go back to automatic when already automatic', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
    );

    await tester.tap(find.text('여행 전'));
    await tester.pumpAndSettle();

    final revert = tester.widget<PopupMenuItem<Object?>>(
      _menuItem('자동으로 되돌리기 (자동: 여행 전)'),
    );
    expect(revert.enabled, isFalse);
  });

  group('격자', () {
    test('puts 2 cards in a row on phones and 3 or 4 on tablets', () {
      expect(tripGridColumns(360), 2);
      expect(tripGridColumns(599), 2);
      expect(tripGridColumns(600), 3);
      expect(tripGridColumns(899), 3);
      expect(tripGridColumns(900), 4);
      expect(tripGridColumns(1280), 4);
    });

    testWidgets('shows square cards two in a row on a phone', (tester) async {
      // 휴대폰 화면: 1080×2340 px, 픽셀 비율 2.625 → 약 411×891 논리 px.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await pumpTestApp(
        tester,
        repository: testRepository([
          testTrip(id: 'a'),
          testTrip(id: 'b', region: '제주'),
          testTrip(id: 'c', region: '강릉'),
        ]),
      );

      final cards = [
        for (var i = 0; i < 3; i++) tester.getRect(find.byType(TripCard).at(i)),
      ];
      expect(cards[1].top, cards[0].top);
      expect(cards[2].top, greaterThan(cards[0].bottom));
      expect(cards[0].width, moreOrLessEquals(cards[0].height));
    });

    testWidgets('keeps the last cards above the + button and navigation bar', (
      tester,
    ) async {
      showNavigationBar(tester);
      await pumpTestApp(
        tester,
        repository: testRepository([
          for (var i = 0; i < 9; i++) testTrip(id: 'trip-$i'),
        ]),
      );

      await tester.drag(find.byType(GridView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final lastCard = tester.getRect(find.byType(TripCard).last);
      expect(lastCard.bottom, lessThanOrEqualTo(fab.top));
    });

    testWidgets('outlines the trip going on now', (tester) async {
      await pumpTestApp(
        tester,
        repository: testRepository([
          testTrip(
            id: 'jeju',
            dates: TripDates(LocalDate(2026, 10, 14), LocalDate(2026, 10, 17)),
          ),
        ]),
      );

      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppPalette.coral);
    });
  });
}

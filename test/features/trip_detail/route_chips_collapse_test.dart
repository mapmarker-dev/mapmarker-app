import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_day_chips.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/memory_route_chips_store.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

Future<void> _pump(WidgetTester tester, MemoryRouteChipsStore store) async {
  usePortraitPhone(tester);
  await pumpTestApp(
    tester,
    repository: testRepository(
      [testTrip(id: 'trip', region: '경주', nights: 2)],
      [testStop('a'), testLodging('hotel', order: 1), testStop('b', day: 2)],
    ),
    location: Routes.trip('trip'),
    routeChipsStore: store,
  );
}

Finder get _summary => find.byType(RouteChipsSummary);

Finder get _chips => find.byType(RouteDayChips);

Future<void> _collapse(WidgetTester tester) async {
  await tester.tap(find.byTooltip('보기 접기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('collapses the chips into a summary at the same spot', (
    tester,
  ) async {
    final store = MemoryRouteChipsStore();
    await _pump(tester, store);
    await tapChip(tester, '2일차');
    final top = mapScene(tester).padding.top;
    // 접기 버튼은 첫 줄 맨 앞, "전체" 칩 앞이다.
    final button = tester.getRect(find.byTooltip('보기 접기'));
    expect(button.right, lessThan(tester.getRect(find.text('전체')).left));

    await _collapse(tester);

    expect(_chips, findsNothing);
    expect(
      find.descendant(of: _summary, matching: find.text('2일차, 숙소와 후보 보기')),
      findsOne,
    );
    // 펼치는 알약은 접기 버튼과 같은 자리에서 시작한다.
    final pill = tester.getRect(_summary);
    expect(pill.left, button.left);
    expect(pill.center.dy, closeTo(button.center.dy, 1));
    expect(store.collapsed, isTrue);
    // 칩이 덮던 자리만큼 지도가 넓어진다.
    expect(mapScene(tester).padding.top, lessThan(top));

    await tester.tap(_summary);
    await tester.pumpAndSettle();

    expect(_chips, findsOne);
    expect(_summary, findsNothing);
    expect(store.collapsed, isFalse);
    expect(mapScene(tester).padding.top, top);
  });

  group('says what is shown along', () {
    Future<String> summaryWith(
      WidgetTester tester, {
      List<String> turnOff = const [],
      String? view,
    }) async {
      await _pump(tester, MemoryRouteChipsStore());
      for (final chip in turnOff) {
        await tapChip(tester, chip);
      }
      if (view != null) await tapChip(tester, view);
      await _collapse(tester);
      return tester
          .widgetList<Text>(
            find.descendant(of: _summary, matching: find.byType(Text)),
          )
          .single
          .data!;
    }

    testWidgets('both', (tester) async {
      expect(await summaryWith(tester), '전체, 숙소와 후보 보기');
    });

    testWidgets('lodging only', (tester) async {
      expect(await summaryWith(tester, turnOff: ['후보']), '전체, 숙소 보기');
    });

    testWidgets('candidates only', (tester) async {
      expect(await summaryWith(tester, turnOff: ['숙소']), '전체, 후보 보기');
    });

    testWidgets('nothing when both are off', (tester) async {
      expect(await summaryWith(tester, turnOff: ['숙소', '후보']), '전체');
    });

    testWidgets('only lodging in the candidate view', (tester) async {
      // 후보 목록 보기는 후보가 늘 보여서 후보를 말하지 않는다.
      expect(
        await summaryWith(tester, turnOff: ['후보'], view: '후보 목록'),
        '후보 목록, 숙소 보기',
      );
      await tester.tap(_summary);
      await tester.pumpAndSettle();
      await tapChip(tester, '숙소');
      await _collapse(tester);
      expect(
        find.descendant(of: _summary, matching: find.text('후보 목록')),
        findsOne,
      );
    });
  });

  testWidgets('opens collapsed when it was left collapsed', (tester) async {
    await _pump(tester, MemoryRouteChipsStore(collapsed: true));

    expect(_chips, findsNothing);
    expect(
      find.descendant(of: _summary, matching: find.text('전체, 숙소와 후보 보기')),
      findsOne,
    );
  });
}

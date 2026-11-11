import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/trashed_trip.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/features/trash/trash_screen.dart';
import 'package:mapmarker_app/features/trips/trip_list_screen.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';

/// 메뉴 항목. 메뉴를 연 화면에 같은 글자가 있어도 메뉴 항목으로 좁힌다.
Finder _menuItem(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
);

/// 휴지통 받기 결과를 정해 둘 수 있는 저장소. 정하지 않으면 메모리 저장소의 휴지통이다.
class _TrashRepository extends FlakyTripRepository {
  _TrashRepository(super.inner);

  List<TrashedTrip>? trash;

  @override
  Future<List<TrashedTrip>> fetchTrash() async => trash ?? super.fetchTrash();
}

void main() {
  late _TrashRepository repository;

  String titleOf(String region) => testL10n.defaultTripTitle(
    region: region,
    nights: 1,
    season: Season.spring,
  );

  setUp(() async {
    repository = _TrashRepository(
      testRepository([
        testTrip(id: 'busan'),
        testTrip(id: 'jeju', region: '제주'),
        testTrip(id: 'gangneung', region: '강릉'),
      ]),
    );
    await repository.inner.trashTrip('busan');
    await repository.inner.trashTrip('jeju');
  });

  Future<void> openTrash(WidgetTester tester) =>
      pumpTestApp(tester, repository: repository, location: Routes.trash);

  Finder rowOf(String region) => find.ancestor(
    of: find.text(titleOf(region)),
    matching: find.byType(ListTile),
  );

  Future<void> openRowMenu(WidgetTester tester, String region) async {
    await tester.tap(
      find.descendant(
        of: rowOf(region),
        matching: find.byTooltip(testL10n.trashItemMenuTooltip),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens from the trip list menu and goes back', (tester) async {
    await pumpTestApp(tester, repository: repository);

    await tester.tap(find.byTooltip(testL10n.moreMenuTooltip));
    await tester.pumpAndSettle();
    await tester.tap(_menuItem(testL10n.trash));
    await tester.pumpAndSettle();

    expect(find.byType(TrashScreen), findsOneWidget);
    expect(find.text(titleOf('부산')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TripListScreen), findsOneWidget);
  });

  testWidgets('shows a hint when the trash is empty', (tester) async {
    await repository.inner.deleteTripForever('busan');
    await repository.inner.deleteTripForever('jeju');

    await openTrash(tester);

    expect(find.text(testL10n.trashEmpty), findsOneWidget);
  });

  testWidgets('lists trashed trips with their region and days left', (
    tester,
  ) async {
    final now = testNow.toUtc();
    TrashedTrip trashed(String id, String region, Duration left) => TrashedTrip(
      trip: testTrip(id: id, region: region),
      deletedAt: now.subtract(const Duration(days: 30)).add(left),
      purgeAt: now.add(left),
    );
    repository.trash = [
      trashed('busan', '부산', const Duration(days: 30)),
      trashed('jeju', '제주', const Duration(days: 2, hours: 3)),
      trashed('gangneung', '강릉', const Duration(hours: 5)),
    ];

    await openTrash(tester);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => ((tile.title! as Text).data));
    expect(titles, [titleOf('부산'), titleOf('제주'), titleOf('강릉')]);
    expect(
      find.descendant(
        of: rowOf('부산'),
        matching: find.text(
          testL10n.trashItemSummary('부산', testL10n.trashPurgeInDays(30)),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rowOf('제주'),
        matching: find.text(
          testL10n.trashItemSummary('제주', testL10n.trashPurgeInDays(3)),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rowOf('강릉'),
        matching: find.text(
          testL10n.trashItemSummary('강릉', testL10n.trashPurgeWithinDay),
        ),
      ),
      findsOneWidget,
    );
  });

  test('counts days left up to the purge, and the last day as zero', () {
    final now = DateTime.utc(2026, 11, 10, 9);

    expect(trashDaysLeft(now.add(const Duration(days: 30)), now), 30);
    expect(
      trashDaysLeft(now.add(const Duration(days: 29, minutes: 1)), now),
      30,
    );
    expect(trashDaysLeft(now.add(const Duration(days: 1, hours: 1)), now), 2);
    expect(trashDaysLeft(now.add(const Duration(days: 1)), now), 1);
    expect(trashDaysLeft(now.add(const Duration(hours: 23)), now), 0);
    expect(trashDaysLeft(now.subtract(const Duration(hours: 1)), now), 0);
  });

  group('restoring', () {
    testWidgets('takes the trip out of the trash and back to the list', (
      tester,
    ) async {
      await openTrash(tester);

      await openRowMenu(tester, '부산');
      await tester.tap(_menuItem(testL10n.restoreTrip));
      await tester.pumpAndSettle();

      expect(find.text(titleOf('부산')), findsNothing);
      expect(find.text(titleOf('제주')), findsOneWidget);
      expect(find.text(testL10n.tripRestored(titleOf('부산'))), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(titleOf('부산')), findsOneWidget);
      expect(find.text(titleOf('제주')), findsNothing);
    });

    testWidgets('shows progress on the row and locks its menu while saving', (
      tester,
    ) async {
      repository.holdWrites = Completer();
      await openTrash(tester);

      await openRowMenu(tester, '부산');
      await tester.tap(_menuItem(testL10n.restoreTrip));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(
        find.descendant(
          of: rowOf('부산'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rowOf('부산'),
          matching: find.byTooltip(testL10n.trashItemMenuTooltip),
        ),
        findsNothing,
      );

      repository.holdWrites!.complete();
      await tester.pumpAndSettle();
      expect(find.text(titleOf('부산')), findsNothing);
    });

    testWidgets('says so and keeps the row when it fails', (tester) async {
      repository.failWrites = ApiFailure.network;
      await openTrash(tester);

      await openRowMenu(tester, '부산');
      await tester.tap(_menuItem(testL10n.restoreTrip));
      await tester.pumpAndSettle();

      expect(find.text(testL10n.saveFailedNetwork), findsOneWidget);
      expect(find.text(titleOf('부산')), findsOneWidget);
      expect(
        find.descendant(
          of: rowOf('부산'),
          matching: find.byTooltip(testL10n.trashItemMenuTooltip),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reloads the trash when the trip is no longer there', (
      tester,
    ) async {
      await openTrash(tester);
      // 다른 기기에서 영구 삭제했다.
      await repository.inner.deleteTripForever('busan');
      repository.failWrites = ApiFailure.notFound;

      await openRowMenu(tester, '부산');
      await tester.tap(_menuItem(testL10n.restoreTrip));
      await tester.pumpAndSettle();

      expect(find.text(testL10n.restoreGone), findsOneWidget);
      expect(find.text(titleOf('부산')), findsNothing);
      expect(find.text(titleOf('제주')), findsOneWidget);
    });
  });

  group('deleting for good', () {
    Future<void> openDelete(WidgetTester tester) async {
      await openTrash(tester);
      await openRowMenu(tester, '부산');
      await tester.tap(_menuItem(testL10n.deleteTripForever));
      await tester.pumpAndSettle();
    }

    Finder confirmButton() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, testL10n.deleteTripForever),
    );

    testWidgets('asks first and deletes the trip', (tester) async {
      await openDelete(tester);

      expect(find.text(testL10n.deleteForeverTitle), findsOneWidget);
      expect(
        find.text(testL10n.deleteForeverMessage(titleOf('부산'))),
        findsOneWidget,
      );
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(titleOf('부산')), findsNothing);
      expect(
        [for (final t in await repository.inner.fetchTrash()) t.trip.id],
        ['jeju'],
      );
    });

    testWidgets('keeps the trip when cancelled', (tester) async {
      await openDelete(tester);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text(titleOf('부산')), findsOneWidget);
    });

    testWidgets('waits in the dialog and says so there when it fails', (
      tester,
    ) async {
      repository.failWrites = ApiFailure.network;
      await openDelete(tester);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(testL10n.saveFailedNetwork),
        ),
        findsOneWidget,
      );
    });
  });

  group('when the server fails', () {
    testWidgets('offers a retry when the trash cannot be loaded', (
      tester,
    ) async {
      repository.failLoads = ApiFailure.network;
      await openTrash(tester);

      expect(find.text(testL10n.trashLoadFailed), findsOneWidget);
      repository.failLoads = null;
      await tester.tap(find.text(testL10n.retry));
      await tester.pumpAndSettle();

      expect(find.text(titleOf('부산')), findsOneWidget);
    });

    testWidgets('refreshes when pulled down and says so when it fails', (
      tester,
    ) async {
      await openTrash(tester);
      await repository.inner.restoreTrip('jeju');

      await tester.fling(find.text(titleOf('부산')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text(titleOf('제주')), findsNothing);

      repository.failLoads = ApiFailure.network;
      await tester.fling(find.text(titleOf('부산')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text(testL10n.refreshFailed), findsOneWidget);
      expect(find.text(titleOf('부산')), findsOneWidget);
    });
  });
}

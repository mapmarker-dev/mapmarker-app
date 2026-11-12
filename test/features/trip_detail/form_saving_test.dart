import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/stop_form_dialog.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/transport_form_dialog.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

// 입력 화면과 버튼은 저장되기 전까지 닫히지 않는다. 실패하면 입력한 그대로 남고 안내는 그 화면 안에 뜬다.
// 전체 화면 입력 창 아래의 스낵바는 가려서 보이지 않는다.

/// 1일차: a > b.
FlakyTripRepository _repository() => FlakyTripRepository(
  testRepository(
    [testTrip(id: 'jeju', region: '제주')],
    [
      testStop('a', tripId: 'jeju', kind: StopKind.tour),
      testStop('b', tripId: 'jeju', order: 1),
    ],
  ),
);

/// 1일차: hotel(숙소) > a. 그날 밤 숙소가 없어서 "오늘 밤은 ‘hotel’에서 묵기"가 있다.
FlakyTripRepository _lodgingRepository() => FlakyTripRepository(
  testRepository(
    [testTrip(id: 'jeju', region: '제주')],
    [
      testStop('hotel', tripId: 'jeju', kind: StopKind.lodging),
      testStop('a', tripId: 'jeju', order: 1, kind: StopKind.tour),
    ],
  ),
);

/// 넓은 화면(오른쪽 패널)에서 1일차 목록을 연다.
Future<ProviderContainer> _openDayOne(
  WidgetTester tester,
  FlakyTripRepository repository,
) async {
  tester.view.physicalSize =
      const Size(1280, 800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final container = await pumpTestApp(
    tester,
    repository: repository,
    location: Routes.trip('jeju'),
  );
  await tester.tap(
    find.ancestor(
      of: find.text('1일차'),
      matching: find.byWidgetPredicate((w) => w is ChoiceChip),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// 저장을 기다리는 동안에는 진행 표시가 계속 돌아서 pumpAndSettle을 쓸 수 없다.
Future<void> _pumpWhileSaving(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder _inDialog<T extends Widget>(Finder finder) =>
    find.descendant(of: find.byType(T), matching: finder);

Finder _inStopTile(String id, Finder finder) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ItineraryStopTile && w.stop.id == id),
  matching: finder,
);

Future<void> _openStopForm(WidgetTester tester, String id) async {
  await tester.tap(find.text(id));
  await tester.pumpAndSettle();
  await tester.tap(_inStopTile(id, find.byTooltip('장소 편집')));
  await tester.pumpAndSettle();
}

Finder get _stopSave => _inDialog<StopFormDialog>(find.text('저장'));

Finder get _stopName =>
    _inDialog<StopFormDialog>(find.widgetWithText(TextField, '이름'));

void main() {
  testWidgets('keeps the rename dialog open with the typed title until it is '
      'saved', (tester) async {
    final repository = _repository()
      ..holdWrites = Completer()
      ..failWrites = ApiFailure.server;
    await pumpTestApp(
      tester,
      repository: repository,
      location: Routes.trip('jeju'),
    );
    await tester.tap(find.byTooltip('제목 바꾸기'));
    await tester.pumpAndSettle();
    final field = _inDialog<AlertDialog>(find.byType(TextField));
    await tester.enterText(field, '가족 여행');

    await tester.tap(find.text('저장'));
    await _pumpWhileSaving(tester);

    // 저장하는 동안: 창은 열려 있고, 진행 표시가 돌고, 고칠 수 없다.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      _inDialog<AlertDialog>(find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(field).enabled, isFalse);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    // 실패: 입력한 제목이 남고, 안내는 창 안에 뜬다.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '가족 여행');
    expect(
      _inDialog<AlertDialog>(find.text(testL10n.saveFailed)),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);

    repository
      ..holdWrites = null
      ..failWrites = null;
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('가족 여행'), findsOneWidget);
  });

  testWidgets('keeps the stop form open with what was typed until it is '
      'saved', (tester) async {
    final repository = _repository()
      ..holdWrites = Completer()
      ..failWrites = ApiFailure.network;
    final container = await _openDayOne(tester, repository);
    await _openStopForm(tester, 'a');
    await tester.enterText(_stopName, '용두암');

    await tester.tap(_stopSave);
    await _pumpWhileSaving(tester);

    expect(find.byType(StopFormDialog), findsOneWidget);
    expect(
      _inDialog<StopFormDialog>(find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(_stopName).enabled, isFalse);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(StopFormDialog), findsOneWidget);
    expect(tester.widget<TextField>(_stopName).controller!.text, '용두암');
    expect(
      _inDialog<StopFormDialog>(find.text(testL10n.saveFailedNetwork)),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);

    repository
      ..holdWrites = null
      ..failWrites = null;
    await tester.tap(_stopSave);
    await tester.pumpAndSettle();

    expect(find.byType(StopFormDialog), findsNothing);
    final route = container.read(tripRouteProvider('jeju')).value!;
    expect(route.stopById('a')!.name, '용두암');
  });

  testWidgets('keeps the new stop form open when adding fails', (tester) async {
    final repository = _repository()..failWrites = ApiFailure.network;
    final container = await _openDayOne(tester, repository);
    await tapMap(tester, const LatLng(35.2, 129.2), placeName: '오름');
    await tester.tap(find.widgetWithText(FilledButton, '동선에 넣기'));
    await tester.pumpAndSettle();

    await tester.tap(_stopSave);
    await tester.pumpAndSettle();

    expect(find.byType(StopFormDialog), findsOneWidget);
    expect(
      _inDialog<StopFormDialog>(find.text(testL10n.saveFailedNetwork)),
      findsOneWidget,
    );

    repository.failWrites = null;
    await tester.tap(_stopSave);
    await tester.pumpAndSettle();

    expect(find.byType(StopFormDialog), findsNothing);
    final route = container.read(tripRouteProvider('jeju')).value!;
    expect(route.stops.map((s) => s.name), contains('오름'));
  });

  testWidgets('shows progress on delete and says inside the stop form when '
      'deleting fails', (tester) async {
    final repository = _repository()
      ..holdWrites = Completer()
      ..failWrites = ApiFailure.network;
    final container = await _openDayOne(tester, repository);
    await _openStopForm(tester, 'a');

    final delete = _inDialog<StopFormDialog>(
      find.widgetWithText(OutlinedButton, '장소 지우기'),
    );
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(_inDialog<AlertDialog>(find.text('지우기')));
    await _pumpWhileSaving(tester);

    expect(
      find.descendant(
        of: delete,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(delete).onPressed, isNull);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(StopFormDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      _inDialog<StopFormDialog>(find.text(testL10n.saveFailedNetwork)),
      findsOneWidget,
    );
    final route = container.read(tripRouteProvider('jeju')).value!;
    expect(route.stopById('a'), isNotNull);
  });

  testWidgets('keeps the transport form open with what was chosen until it '
      'is saved', (tester) async {
    final repository = _repository()..failWrites = ApiFailure.network;
    final container = await _openDayOne(tester, repository);
    await tester.tap(find.byType(ItinerarySegmentTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이동 수단 고치기'));
    await tester.pumpAndSettle();
    await tester.tap(
      _inDialog<TransportFormDialog>(find.widgetWithText(ActionChip, '도보')),
    );
    await tester.pumpAndSettle();

    await tester.tap(_inDialog<TransportFormDialog>(find.text('저장')));
    await tester.pumpAndSettle();

    expect(find.byType(TransportFormDialog), findsOneWidget);
    expect(
      _inDialog<TransportFormDialog>(find.text(testL10n.saveFailedNetwork)),
      findsOneWidget,
    );

    repository.failWrites = null;
    await tester.tap(_inDialog<TransportFormDialog>(find.text('저장')));
    await tester.pumpAndSettle();

    expect(find.byType(TransportFormDialog), findsNothing);
    final route = container.read(tripRouteProvider('jeju')).value!;
    expect(route.segments.single.legs.single.mode, TransportMode.walk);
  });

  testWidgets('shows progress on the stay button until the lodging is added', (
    tester,
  ) async {
    final repository = _lodgingRepository()..holdWrites = Completer();
    final container = await _openDayOne(tester, repository);
    final stay = find.widgetWithText(
      OutlinedButton,
      testL10n.stayTonight('hotel'),
    );

    await tester.tap(stay);
    await _pumpWhileSaving(tester);

    expect(
      find.descendant(
        of: stay,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(stay).onPressed, isNull);

    repository.holdWrites!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final route = container.read(tripRouteProvider('jeju')).value!;
    expect(route.stops, hasLength(3));
  });
}

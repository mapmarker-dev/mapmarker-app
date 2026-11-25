import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/share/image_sharing.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/features/export/export_screen.dart';
import 'package:mapmarker_app/features/export/widgets/export_canvas.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

import '../../helpers/fake_image_sharing.dart';
import '../../helpers/fake_map.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

final _trip = testTrip(
  id: 'trip',
  region: '제주',
  dates: TripDates(LocalDate(2026, 10, 20), LocalDate(2026, 10, 22)),
);

final _stops = [
  testStop('용두암', latitude: 33.52, longitude: 126.30),
  testStop(
    '동문시장',
    order: 1,
    kind: StopKind.food,
    latitude: 33.40,
    longitude: 126.45,
  ),
  testStop(
    '제주 호텔',
    order: 2,
    kind: StopKind.lodging,
    latitude: 33.50,
    longitude: 126.62,
  ),
  testStop('성산', day: 2, latitude: 33.46, longitude: 126.94),
  testStop('섭지코지', day: 2, order: 1, latitude: 33.30, longitude: 126.80),
];

MemoryTripRepository _repository() => testRepository([_trip], _stops);

Future<void> _openExport(
  WidgetTester tester, {
  FakeImageSharing? sharing,
  bool mapCaptureFails = false,
  String? location,
}) async {
  usePortraitPhone(tester);
  await pumpTestApp(
    tester,
    repository: _repository(),
    location: location ?? '/trips/trip/export',
    imageSharing: sharing,
    mapCaptureFails: mapCaptureFails,
  );
}

/// 저장과 공유는 미리보기를 이미지로 바꾸느라 실제 시간이 필요하다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

ChoiceChip _rangeChip(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
);

FilterChip _toggleChip(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(FilterChip)),
);

Finder _inImage(Finder finder) =>
    find.descendant(of: find.byType(ExportCanvas), matching: finder);

void main() {
  testWidgets(
    'opens from the title bar with the day and lodging being viewed',
    (tester) async {
      usePortraitPhone(tester);
      await pumpTestApp(
        tester,
        repository: _repository(),
        location: '/trips/trip',
      );
      await tapChip(tester, '2일차');
      await tapChip(tester, '숙소');

      await tester.tap(find.byTooltip('이미지 만들기'));
      await tester.pumpAndSettle();

      expect(find.byType(ExportScreen), findsOneWidget);
      expect(_rangeChip(tester, '2일차').selected, isTrue);
      expect(_toggleChip(tester, '숙소').selected, isFalse);
      expect(_inImage(find.text('제주 호텔')), findsNothing);

      // 뒤로 가면 동선 화면이다.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ExportScreen), findsNothing);
      expect(find.byTooltip('이미지 만들기'), findsOneWidget);
    },
  );

  testWidgets('draws the trip title, its period and the places', (
    tester,
  ) async {
    await _openExport(tester);

    expect(_inImage(find.text(_trip.title)), findsOneWidget);
    expect(_inImage(find.text(testL10n.tripSummaryOf(_trip))), findsOneWidget);
    for (final name in ['용두암', '동문시장', '제주 호텔', '성산', '섭지코지']) {
      expect(_inImage(find.text(name)), findsOneWidget, reason: name);
    }
    expect(_inImage(find.text('MapMarker')), findsOneWidget);
    // 사진이 있는 장소가 없으면 사진 칩이 없다.
    expect(find.widgetWithText(FilterChip, '사진'), findsNothing);
  });

  testWidgets('turning the title off removes the card and refits the map', (
    tester,
  ) async {
    await _openExport(tester);
    double top() => tester
        .widget<FakeCaptureMap>(find.byType(FakeCaptureMap))
        .frame
        .padding
        .top;
    final withTitle = top();

    await tester.tap(find.widgetWithText(FilterChip, '제목'));
    await tester.pumpAndSettle();

    expect(_inImage(find.text(_trip.title)), findsNothing);
    expect(top(), lessThan(withTitle));
  });

  testWidgets('a day range draws only that day', (tester) async {
    await _openExport(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '1일차'));
    await tester.pumpAndSettle();

    expect(_inImage(find.text('용두암')), findsOneWidget);
    expect(_inImage(find.text('성산')), findsNothing);
    expect(_inImage(find.text('1일차, 10월 20일 (화)')), findsOneWidget);
  });

  testWidgets('a day without places says so and cannot be saved', (
    tester,
  ) async {
    await _openExport(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '3일차'));
    await tester.pumpAndSettle();

    expect(find.text('이 범위에는 장소가 없습니다.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '사진첩에 저장'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('saves the image to the gallery', (tester) async {
    final sharing = FakeImageSharing();
    await _openExport(tester, sharing: sharing);

    await tester.tap(find.text('사진첩에 저장'));
    await _settle(tester);

    expect(sharing.saved, hasLength(1));
    final (name, png) = sharing.saved.single;
    expect(name, 'MapMarker_20261015_120000');
    // PNG 시그니처.
    expect(png.take(4), [0x89, 0x50, 0x4E, 0x47]);
    expect(find.text('사진첩에 저장했습니다.'), findsOneWidget);
  });

  testWidgets('asks to open settings when the gallery is not allowed', (
    tester,
  ) async {
    final sharing = FakeImageSharing(saveResult: GallerySaveResult.denied);
    await _openExport(tester, sharing: sharing);

    await tester.tap(find.text('사진첩에 저장'));
    await _settle(tester);

    expect(find.text('사진첩에 저장하려면 권한이 필요합니다.'), findsOneWidget);
    await tester.tap(find.widgetWithText(SnackBarAction, '설정'));
    await tester.pumpAndSettle();
    expect(sharing.settingsOpened, 1);
  });

  testWidgets('tells when saving fails', (tester) async {
    final sharing = FakeImageSharing(saveResult: GallerySaveResult.failed);
    await _openExport(tester, sharing: sharing);

    await tester.tap(find.text('사진첩에 저장'));
    await _settle(tester);

    expect(find.text('저장하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
  });

  testWidgets('shares the image', (tester) async {
    final sharing = FakeImageSharing();
    await _openExport(tester, sharing: sharing);

    await tester.tap(find.text('공유'));
    await _settle(tester);

    expect(sharing.shared, hasLength(1));
    expect(sharing.saved, isEmpty);
  });

  testWidgets('tells when sharing fails', (tester) async {
    final sharing = FakeImageSharing()..shareFails = true;
    await _openExport(tester, sharing: sharing);

    await tester.tap(find.text('공유'));
    await _settle(tester);

    expect(find.text('공유하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
  });

  testWidgets('tells when the map cannot be loaded', (tester) async {
    await _openExport(tester, mapCaptureFails: true);

    expect(find.text('지도를 불러오지 못했습니다. 인터넷 연결을 확인해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '공유'))
          .onPressed,
      isNull,
    );
  });

  group('moving the map', () {
    MapFrame frame(WidgetTester tester) =>
        tester.widget<FakeCaptureMap>(find.byType(FakeCaptureMap)).frame;

    /// 지금 미리보기 가운데에 보이는 곳과 줌(가짜 지도가 찍은 것과 같다).
    (LatLng, double) middle(WidgetTester tester) {
      final size = tester.getSize(find.byType(FakeCaptureMap));
      final capture = fakeCapture(frame(tester), size);
      return (
        capture.projection.toLatLng(size.center(Offset.zero)),
        capture.zoom,
      );
    }

    bool fitPressed(WidgetTester tester) => tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('동선에 맞추기'),
            matching: find.byType(IconButton),
          ),
        )
        .isSelected!;

    testWidgets('dragging moves the map and the fit button brings it back', (
      tester,
    ) async {
      await _openExport(tester);
      final (before, zoom) = middle(tester);
      expect(fitPressed(tester), isFalse);
      expect(find.text('끌거나 두 손가락으로 늘려 지도 위치를 바꿀 수 있습니다.'), findsOneWidget);

      // 왼쪽으로 끌면 오른쪽(동쪽)에 있던 곳이 가운데로 온다.
      await tester.drag(find.byType(ExportCanvas), const Offset(-120, 0));
      // 다시 찍는 동안은 위쪽 얇은 막대만 뜬다.
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);

      final moved = frame(tester);
      expect(moved.bounds, isNull);
      expect(moved.center!.longitude, greaterThan(before.longitude));
      expect(moved.center!.latitude, closeTo(before.latitude, 0.01));
      expect(moved.zoom, closeTo(zoom, 0.01));
      expect(fitPressed(tester), isTrue);
      // 다시 찍은 뒤에는 저장할 수 있다.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '공유'))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byTooltip('동선에 맞추기'));
      await tester.pumpAndSettle();

      expect(frame(tester).bounds, isNotNull);
      expect(fitPressed(tester), isFalse);
    });

    testWidgets('pinching out zooms in', (tester) async {
      await _openExport(tester);
      final (_, zoom) = middle(tester);
      final center = tester.getCenter(find.byType(ExportCanvas));

      final first = await tester.startGesture(center - const Offset(40, 0));
      final second = await tester.startGesture(center + const Offset(40, 0));
      for (var step = 1; step <= 8; step++) {
        await first.moveTo(center - Offset(40.0 + step * 10, 0));
        await second.moveTo(center + Offset(40.0 + step * 10, 0));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(frame(tester).zoom, greaterThan(zoom + 0.5));
    });

    testWidgets('chips keep the chosen place but a new range refits', (
      tester,
    ) async {
      await _openExport(tester);
      await tester.drag(find.byType(ExportCanvas), const Offset(-120, 40));
      await tester.pumpAndSettle();
      final moved = frame(tester);

      await tester.tap(find.widgetWithText(FilterChip, '제목'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '숙소'));
      await tester.pumpAndSettle();

      expect(frame(tester), moved);

      await tester.tap(find.widgetWithText(ChoiceChip, '1일차'));
      await tester.pumpAndSettle();

      expect(frame(tester).bounds, isNotNull);
    });
  });
}

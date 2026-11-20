import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/location/location_source.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/core/time/zoned_time.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';

import '../../helpers/fake_location.dart';
import '../../helpers/fake_map.dart';
import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 오늘(2026-10-15)이 2일차인 2박 3일 여행.
final _during = TripDates(LocalDate(2026, 10, 14), LocalDate(2026, 10, 16));

/// 이미 끝난 여행(10월 1일~3일).
final _after = TripDates(LocalDate(2026, 10, 1), LocalDate(2026, 10, 3));

/// 다음 달 여행.
final _before = TripDates(LocalDate(2026, 11, 1), LocalDate(2026, 11, 3));

Stop _stop(String name, {int day = 2, int order = 0, LocalTime? planned}) =>
    testStop(name, day: day, order: order).copyWith(plannedTime: () => planned);

/// 2일차: 대릉원(09:30 예정) > 교리김밥.
List<Stop> _stops() => [
  _stop('대릉원', planned: const LocalTime(9, 30)),
  _stop('교리김밥', order: 1),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required TripDates dates,
  List<Stop>? stops,
  List<Candidate> candidates = const [],
  TripRepository? repository,
  LocationSource? locationSource,
}) => pumpTestApp(
  tester,
  repository:
      repository ??
      testRepository(
        [testTrip(id: 'trip', region: '경주', dates: dates)],
        stops ?? _stops(),
        candidates,
      ),
  location: Routes.trip('trip'),
  locationSource: locationSource,
);

Stop _saved(ProviderContainer container, String id) =>
    container.read(tripRouteProvider('trip')).value!.stopById(id)!;

Future<void> _expand(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// 장소 줄 오른쪽의 방문 동그라미.
Finder _check(String name) => find.byTooltip('$name 방문');

bool _checked(WidgetTester tester, String name) =>
    tester
        .widget<IconButton>(
          find.ancestor(of: _check(name), matching: find.byType(IconButton)),
        )
        .isSelected ==
    true;

Finder get _dialog => find.byType(AlertDialog);

Finder _inDialog(Finder finder) =>
    find.descendant(of: _dialog, matching: finder);

/// [instant]를 장소 시간대(서울)의 "오후 12:00"처럼 쓴다. 테스트 기기의 시간대와 상관없다.
String _seoulTime(DateTime instant) {
  final time = zonedParts(instant, Stop.defaultTimeZone).time;
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.hour < 12 ? '오전' : '오후'} $hour:$minute';
}

void main() {
  group('visits', _visitTests);
  group('my location', _locationTests);
  group('nearby candidates', _nearbyTests);

  testWidgets('opens on today during the trip', (tester) async {
    final container = await _pump(tester, dates: _during);
    expect(container.read(routeChoiceProvider('trip')).day, 2);
    expect(find.textContaining('2일차, 10월 15일'), findsOneWidget);
  });

  testWidgets('opens the whole trip before it starts', (tester) async {
    final container = await _pump(tester, dates: _before);
    expect(container.read(routeChoiceProvider('trip')).day, isNull);
  });
}

void _visitTests() {
  testWidgets('marks a place visited after confirming, at the current time', (
    tester,
  ) async {
    final container = await _pump(tester, dates: _during);

    await tester.tap(_check('교리김밥'));
    await tester.pumpAndSettle();

    final now = testNow.toUtc();
    expect(_inDialog(find.text('교리김밥 방문 완료')), findsOneWidget);
    expect(
      _inDialog(find.textContaining('10월 15일 (목) ${_seoulTime(now)}에')),
      findsOneWidget,
    );

    await tester.tap(_inDialog(find.text('방문 완료')));
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    final saved = _saved(container, '교리김밥');
    expect(saved.visited, isTrue);
    expect(saved.visitedAt, now);
    // 줄은 방문 시각을 보여 주고 동그라미가 채워진다. 지도 마커는 번호 그대로다.
    expect(find.text('기타, ${_seoulTime(now)} 방문'), findsOneWidget);
    expect(_checked(tester, '교리김밥'), isTrue);
    final marker = mapScene(tester).markers.firstWhere((m) => m.id == '교리김밥');
    expect(marker.look.icon, isNull);
    expect(marker.look.label, isNotNull);
  });

  testWidgets('cancelling the dialog keeps the place unvisited', (
    tester,
  ) async {
    final container = await _pump(tester, dates: _during);

    await tester.tap(_check('교리김밥'));
    await tester.pumpAndSettle();
    await tester.tap(_inDialog(find.text('취소')));
    await tester.pumpAndSettle();

    expect(_saved(container, '교리김밥').visited, isFalse);
  });

  testWidgets('undoes a visit after confirming, closing keeps it', (
    tester,
  ) async {
    final at = DateTime.utc(2026, 10, 15, 0, 41);
    final container = await _pump(
      tester,
      dates: _during,
      stops: [
        _stop(
          '대릉원',
          planned: const LocalTime(9, 30),
        ).copyWith(visitedAt: () => at),
      ],
    );
    expect(find.text('기타, 오전 9:30 예정, ${_seoulTime(at)} 방문'), findsOneWidget);

    await tester.tap(_check('대릉원'));
    await tester.pumpAndSettle();
    expect(_inDialog(find.text('대릉원 방문 취소')), findsOneWidget);
    expect(
      _inDialog(find.text('10월 15일 (목) ${_seoulTime(at)} 방문 기록이 지워집니다.')),
      findsOneWidget,
    );
    // 닫는 버튼은 [방문 취소]와 헷갈리지 않게 "닫기"다.
    expect(_inDialog(find.text('취소')), findsNothing);

    await tester.tap(_inDialog(find.text('닫기')));
    await tester.pumpAndSettle();
    expect(_saved(container, '대릉원').visitedAt, at);

    await tester.tap(_check('대릉원'));
    await tester.pumpAndSettle();
    await tester.tap(_inDialog(find.text('방문 취소')));
    await tester.pumpAndSettle();

    final saved = _saved(container, '대릉원');
    expect(saved.visited, isFalse);
    expect(saved.visitedAt, isNull);
    expect(_checked(tester, '대릉원'), isFalse);
  });

  testWidgets('keeps the dialog open and says so when saving fails', (
    tester,
  ) async {
    final repository = FlakyTripRepository(
      testRepository([
        testTrip(id: 'trip', region: '경주', dates: _during),
      ], _stops()),
    );
    final container = await _pump(
      tester,
      dates: _during,
      repository: repository,
    );
    repository.failWrites = ApiFailure.network;

    await tester.tap(_check('교리김밥'));
    await tester.pumpAndSettle();
    await tester.tap(_inDialog(find.text('방문 완료')));
    await tester.pumpAndSettle();

    expect(_dialog, findsOneWidget);
    expect(_inDialog(find.text(testL10n.saveFailedNetwork)), findsOneWidget);
    expect(_saved(container, '교리김밥').visited, isFalse);
  });

  testWidgets('has no visit check before the trip', (tester) async {
    await _pump(tester, dates: _before);
    await tapChip(tester, '2일차');
    await _expand(tester, '교리김밥');

    expect(find.text('교리김밥'), findsWidgets);
    expect(_check('교리김밥'), findsNothing);
  });

  testWidgets('records the planned day after the trip ended', (tester) async {
    final container = await _pump(tester, dates: _after);
    await tapChip(tester, '2일차');
    await _expand(tester, '대릉원');

    await tester.tap(_check('대릉원'));
    await tester.pumpAndSettle();
    expect(
      _inDialog(find.textContaining('10월 2일 (금) 오전 9:30에')),
      findsOneWidget,
    );
    await tester.tap(_inDialog(find.text('방문 완료')));
    await tester.pumpAndSettle();

    // 10월 2일 오전 9:30(서울) = 00:30 UTC.
    expect(
      _saved(container, '대릉원').visitedAt,
      DateTime.utc(2026, 10, 2, 0, 30),
    );
  });

  testWidgets('edits the visit time in the stop form, a minute at a time', (
    tester,
  ) async {
    final at = DateTime.utc(2026, 10, 15, 3, 41);
    final container = await _pump(
      tester,
      dates: _during,
      stops: [_stop('교리김밥').copyWith(visitedAt: () => at)],
    );
    await _expand(tester, '교리김밥');
    await tester.tap(find.byTooltip('장소 편집'));
    await tester.pumpAndSettle();

    expect(find.text('방문 시각'), findsOneWidget);
    expect(find.text('10월 15일 (목)'), findsOneWidget);
    await tester.tap(find.text(_seoulTime(at)));
    await tester.pumpAndSettle();

    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.minuteInterval, 1);
    final initial = zonedParts(at, Stop.defaultTimeZone).time;
    expect(wheel.initialDateTime.hour, initial.hour);
    expect(wheel.initialDateTime.minute, initial.minute);
    wheel.onDateTimeChanged(DateTime(2000, 1, 1, 13, 7));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '확인'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    // 10월 15일 오후 1:07(서울) = 04:07 UTC. 날짜는 그대로다.
    expect(
      _saved(container, '교리김밥').visitedAt,
      DateTime.utc(2026, 10, 15, 4, 7),
    );
  });

  testWidgets('edits the visit date within the trip up to today', (
    tester,
  ) async {
    final at = DateTime.utc(2026, 10, 15, 3, 41);
    final container = await _pump(
      tester,
      dates: _during,
      stops: [_stop('교리김밥').copyWith(visitedAt: () => at)],
    );
    await _expand(tester, '교리김밥');
    await tester.tap(find.byTooltip('장소 편집'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('10월 15일 (목)'));
    await tester.pumpAndSettle();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, DateTime(2026, 10, 14));
    // 여행은 16일까지지만 미래는 고를 수 없다.
    expect(picker.lastDate, DateTime(2026, 10, 15));
    await tester.tap(find.text('14'));
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('10월 14일 (수)'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final saved = _saved(container, '교리김밥').visitedAt!;
    expect(saved, at.subtract(const Duration(days: 1)));
  });

  testWidgets('has no visit field for a place not visited', (tester) async {
    await _pump(tester, dates: _during);
    await _expand(tester, '교리김밥');
    await tester.tap(find.byTooltip('장소 편집'));
    await tester.pumpAndSettle();

    expect(find.text('방문 시각'), findsNothing);
  });
}

void _locationTests() {
  const here = LatLng(35.8346, 129.2187);

  testWidgets('shows the location without asking during the trip', (
    tester,
  ) async {
    final location = FakeLocationSource(granted: true);
    await _pump(tester, dates: _during, locationSource: location);
    final camera = mapScene(tester).camera.key;

    expect(location.listening, isTrue);
    location.emit(const LocationFix(here, accuracy: 12));
    // 스트림이 다음 마이크로태스크에 전하고, 그다음 프레임에 그린다.
    await tester.pump();
    await tester.pump();

    expect(mapScene(tester).myLocation, here);
    // 카메라는 그대로다(묻지 않고 켠 위치로 지도를 옮기지 않는다).
    expect(mapScene(tester).camera.key, camera);
    expect(location.asked, 0);
  });

  testWidgets('does not ask or listen on opening before the trip', (
    tester,
  ) async {
    final location = FakeLocationSource(granted: true);
    await _pump(tester, dates: _before, locationSource: location);

    expect(location.listening, isFalse);
    expect(mapScene(tester).myLocation, isNull);
  });

  testWidgets('asks on the button and moves the camera around the location', (
    tester,
  ) async {
    final location = FakeLocationSource();
    await _pump(tester, dates: _before, locationSource: location);

    await tester.tap(find.byTooltip('내 위치'));
    await tester.pump();
    expect(location.asked, 1);
    location.emit(const LocationFix(here));
    await tester.pumpAndSettle();

    final scene = mapScene(tester);
    expect(scene.myLocation, here);
    expect(scene.camera.bounds, boundsAround(here, 1000));

    // 맞추기 버튼을 누르면 동선 맞춤으로 돌아간다.
    await tester.tap(find.byTooltip('동선에 맞추기'));
    await tester.pumpAndSettle();
    expect(mapScene(tester).camera.bounds, isNot(boundsAround(here, 1000)));

    // 다시 누르면 묻지 않고 내 위치로 간다.
    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();
    expect(location.asked, 1);
    expect(mapScene(tester).camera.bounds, boundsAround(here, 1000));
  });

  testWidgets('says why when the permission is denied', (tester) async {
    final location = FakeLocationSource(answer: LocationProblem.denied);
    await _pump(tester, dates: _before, locationSource: location);

    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();

    expect(find.text(testL10n.myLocationDenied), findsOneWidget);
    expect(location.listening, isFalse);
    expect(mapScene(tester).myLocation, isNull);
  });

  testWidgets('offers the app settings when asking is turned off', (
    tester,
  ) async {
    final location = FakeLocationSource(answer: LocationProblem.deniedForever);
    await _pump(tester, dates: _before, locationSource: location);

    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();
    expect(find.text(testL10n.myLocationDeniedForever), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(location.openedAppSettings, 1);
  });

  testWidgets('offers the location settings when the service is off', (
    tester,
  ) async {
    final location = FakeLocationSource(serviceOff: true);
    await _pump(tester, dates: _before, locationSource: location);

    await tester.tap(find.byTooltip('내 위치'));
    await tester.pumpAndSettle();
    expect(find.text(testL10n.myLocationServiceOff), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(location.openedLocationSettings, 1);
  });

  testWidgets('gives up after ten seconds without a location', (tester) async {
    final location = FakeLocationSource(granted: true);
    await _pump(tester, dates: _before, locationSource: location);

    await tester.tap(find.byTooltip('내 위치'));
    await tester.pump();
    expect(location.listening, isTrue);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(find.text(testL10n.myLocationTimeout), findsOneWidget);
    expect(location.listening, isFalse);
  });

  testWidgets('stops listening when leaving the trip', (tester) async {
    final location = FakeLocationSource(granted: true);
    await _pump(tester, dates: _during, locationSource: location);
    expect(location.listening, isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(location.listening, isFalse);
  });
}

void _nearbyTests() {
  // 내 위치에서 북쪽으로 약 2.2km, 330m, 6.7km.
  const here = LatLng(35.8346, 129.2187);
  Candidate candidate(String id, double north) => Candidate(
    id: id,
    tripId: 'trip',
    latitude: here.latitude + north,
    longitude: here.longitude,
    name: id,
  );
  final candidates = [
    candidate('첨성대', 0.02),
    candidate('카페', 0.003),
    candidate('보문호', 0.06),
  ];

  List<String> tileNames(WidgetTester tester) => [
    for (final tile in tester.widgetList<CandidateTile>(
      find.byType(CandidateTile),
    ))
      tile.candidate.name,
  ];

  testWidgets('lists candidates nearest first with their distance', (
    tester,
  ) async {
    final location = FakeLocationSource(granted: true);
    await _pump(
      tester,
      dates: _during,
      candidates: candidates,
      locationSource: location,
    );
    await tapChip(tester, '후보 목록');
    expect(tileNames(tester), ['첨성대', '카페', '보문호']);
    expect(find.text('가까운 순'), findsNothing);

    location.emit(const LocationFix(here));
    await tester.pumpAndSettle();

    expect(tileNames(tester), ['카페', '첨성대', '보문호']);
    expect(find.text('가까운 순'), findsOneWidget);
    expect(find.text('330m'), findsOneWidget);
    expect(find.text('2.2km'), findsOneWidget);
    expect(find.text('6.7km'), findsOneWidget);
  });
}

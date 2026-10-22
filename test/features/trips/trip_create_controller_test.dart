import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/core/time/today.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';
import 'package:mapmarker_app/features/trips/trip_create_controller.dart';

import '../../helpers/test_app.dart';

ProviderContainer _container() {
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => testNow),
      tripRepositoryProvider.overrideWithValue(testRepository()),
    ],
  );
  // 화면 없이도 만들던 여행이 사라지지 않게 붙잡아 둔다.
  container.listen(tripCreateProvider, (_, _) {});
  return container;
}

final _octoberTrip = TripDates(
  LocalDate(2026, 10, 15),
  LocalDate(2026, 10, 17),
);

void main() {
  late ProviderContainer container;
  TripDraft draft() => container.read(tripCreateProvider);
  TripCreateController controller() =>
      container.read(tripCreateProvider.notifier);

  setUp(() => container = _container());

  test('starts with 1박 2일 and no season', () {
    expect(draft().nights, 1);
    expect(draft().season, isNull);
    expect(draft().title, '1박 2일 여행');
    expect(draft().canCreate, isFalse);
  });

  test('fills length and season from the dates', () {
    controller()
      ..setRegion('제주')
      ..setDates(_octoberTrip);

    expect(draft().nights, 2);
    expect(draft().season, Season.autumn);
    expect(draft().title, '제주 2박 3일 가을 여행');
    expect(draft().canCreate, isTrue);
  });

  test('lets the season change even with dates', () {
    controller()
      ..setRegion('제주')
      ..setDates(_octoberTrip)
      ..setSeason(Season.winter);

    expect(draft().title, '제주 2박 3일 겨울 여행');
  });

  test('keeps the length from the dates', () {
    controller()
      ..setDates(_octoberTrip)
      ..setNights(5);

    expect(draft().nights, 2);
  });

  test('keeps length and season when the dates are cleared', () {
    controller()
      ..setDates(_octoberTrip)
      ..clearDates();

    expect(draft().dates, isNull);
    expect(draft().nights, 2);
    expect(draft().season, Season.autumn);

    controller().setNights(4);
    expect(draft().nights, 4);
  });

  test('keeps the length between 당일치기 and 30 nights', () {
    controller().setNights(-1);
    expect(draft().nights, 0);

    controller().setNights(31);
    expect(draft().nights, TripCreateController.maxNights);
  });

  test('stops following once the user edits the title', () {
    controller()
      ..setRegion('부산')
      ..editTitle('가족 여행')
      ..setSeason(Season.spring);

    expect(draft().title, '가족 여행');
  });

  test('follows again after the title is cleared', () {
    controller()
      ..setRegion('부산')
      ..editTitle('가족 여행')
      ..editTitle('  ');

    expect(draft().title, '  ');

    controller().setSeason(Season.spring);
    expect(draft().title, '부산 1박 2일 봄 여행');
  });

  test('creates a trip with the default title', () async {
    controller()
      ..setRegion(' 부산 ')
      ..setSeason(Season.spring)
      ..editTitle('');

    final trip = await controller().create();

    expect(trip.title, '부산 1박 2일 봄 여행');
    expect(trip.region, '부산');
    expect(trip.nights, 1);
    expect(trip.dates, isNull);
    expect(trip.phaseOverride, isNull);
    expect(trip.origin, TripOrigin.manual);
    expect(trip.createdAt, testNow.toUtc());
    // UUID v7: 13번째 글자가 버전이다.
    expect(trip.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7')));
  });

  test('creates a trip with the trimmed title the user wrote', () async {
    controller()
      ..setRegion('제주')
      ..setDates(_octoberTrip)
      ..editTitle(' 가족 여행 ');

    final trip = await controller().create();

    expect(trip.title, '가족 여행');
    expect(trip.dates, _octoberTrip);
    expect(trip.season, Season.autumn);
  });

  test('refuses to create without a region', () {
    controller().setSeason(Season.spring);

    expect(() => controller().create(), throwsStateError);
  });
}

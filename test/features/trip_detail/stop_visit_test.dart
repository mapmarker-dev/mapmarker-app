import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/features/trip_detail/stop_visit.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

void main() {
  // 10월 20일~22일 2박 3일.
  final dates = TripDates(LocalDate(2026, 10, 20), LocalDate(2026, 10, 22));
  final trip = testTrip(id: 'trip', dates: dates);

  group('showsVisitButtons', () {
    test('shows during and after the trip, not before', () {
      expect(showsVisitButtons(trip, LocalDate(2026, 10, 19)), isFalse);
      expect(showsVisitButtons(trip, LocalDate(2026, 10, 20)), isTrue);
      expect(showsVisitButtons(trip, LocalDate(2026, 10, 25)), isTrue);
    });

    test('follows a phase set by hand', () {
      final undated = testTrip(id: 'trip');
      expect(showsVisitButtons(undated, LocalDate(2026, 10, 20)), isFalse);
      expect(
        showsVisitButtons(
          testTrip(id: 'trip', phaseOverride: TripPhase.during),
          LocalDate(2026, 10, 20),
        ),
        isTrue,
      );
    });
  });

  group('defaultVisitTime', () {
    // 서울 10월 21일 오후 3:10.
    final now = DateTime.utc(2026, 10, 21, 6, 10);

    test('is now on the day of the stop or later in the plan', () {
      expect(defaultVisitTime(trip, testStop('a', day: 2), now), now);
      expect(defaultVisitTime(trip, testStop('a', day: 3), now), now);
    });

    test('is now for a trip without dates', () {
      expect(
        defaultVisitTime(testTrip(id: 'trip'), testStop('a', day: 1), now),
        now,
      );
    });

    test('uses the planned time of an earlier day', () {
      final stop = testStop(
        'a',
        day: 1,
      ).copyWith(plannedTime: () => const LocalTime(9, 30));

      // 10월 20일 오전 9:30(서울) = 00:30 UTC.
      expect(
        defaultVisitTime(trip, stop, now),
        DateTime.utc(2026, 10, 20, 0, 30),
      );
    });

    test('uses noon of an earlier day without a planned time', () {
      expect(
        defaultVisitTime(trip, testStop('a', day: 1), now),
        DateTime.utc(2026, 10, 20, 3),
      );
    });

    test('uses the planned day after the trip ended', () {
      final later = DateTime.utc(2026, 11, 2, 1);
      expect(
        defaultVisitTime(trip, testStop('a', day: 3), later),
        DateTime.utc(2026, 10, 22, 3),
      );
    });
  });

  group('visitDateRange', () {
    test('runs from the start to today during the trip', () {
      expect(visitDateRange(trip, LocalDate(2026, 10, 21)), (
        first: LocalDate(2026, 10, 20),
        last: LocalDate(2026, 10, 21),
      ));
    });

    test('runs over the whole trip after it ended', () {
      expect(visitDateRange(trip, LocalDate(2026, 11, 2)), (
        first: LocalDate(2026, 10, 20),
        last: LocalDate(2026, 10, 22),
      ));
    });

    test('is the start day only when the trip moved later', () {
      expect(visitDateRange(trip, LocalDate(2026, 10, 1)), (
        first: LocalDate(2026, 10, 20),
        last: LocalDate(2026, 10, 20),
      ));
    });

    test('is the past year without dates', () {
      expect(visitDateRange(testTrip(id: 'trip'), LocalDate(2026, 10, 21)), (
        first: LocalDate(2025, 10, 21),
        last: LocalDate(2026, 10, 21),
      ));
    });
  });
}

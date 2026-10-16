import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/dev/sample_trips.dart';

void main() {
  test('shows one trip for each phase today', () {
    for (final today in [
      LocalDate(2026, 10, 15),
      LocalDate(2027, 1, 1),
      LocalDate(2028, 2, 29),
    ]) {
      final trips = sampleTrips(
        today: today,
        now: DateTime(today.year, today.month, today.day, 9),
      );

      expect(
        trips.map((trip) => trip.phaseOn(today)),
        unorderedEquals(TripPhase.values),
        reason: '$today',
      );
    }
  });

  test('uses default titles and distinct ids', () {
    final trips = sampleTrips(
      today: LocalDate(2026, 10, 15),
      now: DateTime(2026, 10, 15, 9),
    );

    expect(trips.map((trip) => trip.title), [
      for (final trip in trips) trip.defaultTitle,
    ]);
    expect(trips.map((trip) => trip.id).toSet(), hasLength(trips.length));
  });
}

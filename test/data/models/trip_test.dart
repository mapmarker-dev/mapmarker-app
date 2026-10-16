import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/trip.dart';

Trip _trip({TripDates? dates, int nights = 2, TripPhase? phaseOverride}) {
  final now = DateTime.utc(2026, 10, 1);
  return Trip(
    id: 'trip-1',
    title: '부산 2박 3일 봄 여행',
    region: '부산',
    nights: dates?.nights ?? nights,
    season: Season.spring,
    dates: dates,
    phaseOverride: phaseOverride,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // 일정·제목·기간의 화면 글자는 test/l10n/model_texts_test.dart에서 본다.
  group('일정', () {
    test('counts nights from the dates', () {
      final date = LocalDate(2026, 10, 15);

      expect(TripDates(date, date).nights, 0);
      expect(TripDates(date, LocalDate(2026, 10, 17)).nights, 2);
      expect(
        TripDates(LocalDate(2026, 12, 30), LocalDate(2027, 1, 2)).nights,
        3,
      );
    });
  });

  group('계절', () {
    test('splits months the way the weather service does', () {
      final seasons = [for (var m = 1; m <= 12; m++) Season.ofMonth(m)];

      expect(seasons, [
        Season.winter, // 1
        Season.winter, // 2
        Season.spring, // 3
        Season.spring, // 4
        Season.spring, // 5
        Season.summer, // 6
        Season.summer, // 7
        Season.summer, // 8
        Season.autumn, // 9
        Season.autumn, // 10
        Season.autumn, // 11
        Season.winter, // 12
      ]);
    });

    test('takes the season of the start date', () {
      final dates = TripDates(LocalDate(2026, 11, 29), LocalDate(2026, 12, 2));

      expect(dates.season, Season.autumn);
    });
  });

  group('상태', () {
    final dates = TripDates(LocalDate(2026, 10, 15), LocalDate(2026, 10, 17));

    test('is 전 before the start date', () {
      expect(dates.phaseOn(LocalDate(2026, 10, 14)), TripPhase.before);
    });

    test('is 중 from the start date through the end date', () {
      expect(dates.phaseOn(LocalDate(2026, 10, 15)), TripPhase.during);
      expect(dates.phaseOn(LocalDate(2026, 10, 16)), TripPhase.during);
      expect(dates.phaseOn(LocalDate(2026, 10, 17)), TripPhase.during);
    });

    test('is 후 after the end date', () {
      expect(dates.phaseOn(LocalDate(2026, 10, 18)), TripPhase.after);
    });

    test('is 전 when the trip has no dates', () {
      expect(_trip().phaseOn(LocalDate(2030, 1, 1)), TripPhase.before);
    });

    test('follows the phase the user chose', () {
      final trip = _trip(dates: dates, phaseOverride: TripPhase.during);

      expect(trip.phaseOn(LocalDate(2026, 10, 14)), TripPhase.during);
      expect(trip.autoPhaseOn(LocalDate(2026, 10, 14)), TripPhase.before);
    });

    test('goes back to automatic when the override is cleared', () {
      final trip = _trip(dates: dates, phaseOverride: TripPhase.after);

      final reverted = trip.copyWith(phaseOverride: () => null);

      expect(reverted.phaseOverride, isNull);
      expect(reverted.phaseOn(LocalDate(2026, 10, 16)), TripPhase.during);
    });

    test('keeps the override when copying other fields', () {
      final trip = _trip(phaseOverride: TripPhase.after);

      expect(trip.copyWith(title: '새 제목').phaseOverride, TripPhase.after);
    });
  });

  group('기간', () {
    test('gives the date of each day', () {
      final dates = TripDates(LocalDate(2026, 10, 30), LocalDate(2026, 11, 2));

      expect(dates.dateOfDay(1), LocalDate(2026, 10, 30));
      expect(dates.dateOfDay(4), LocalDate(2026, 11, 2));
    });
  });
}

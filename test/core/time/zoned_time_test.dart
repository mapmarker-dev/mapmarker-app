import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/core/time/zoned_time.dart';

void main() {
  test('reads an instant in the place time zone, not the device one', () {
    final instant = DateTime.utc(2026, 10, 21, 3, 42);

    expect(zonedParts(instant, 'Asia/Seoul'), (
      date: LocalDate(2026, 10, 21),
      time: const LocalTime(12, 42),
    ));
    // 파리는 10월 21일에 서머타임(UTC+2)이다.
    expect(zonedParts(instant, 'Europe/Paris'), (
      date: LocalDate(2026, 10, 21),
      time: const LocalTime(5, 42),
    ));
    // 하와이는 UTC−10이라 전날이다.
    expect(zonedParts(instant, 'Pacific/Honolulu'), (
      date: LocalDate(2026, 10, 20),
      time: const LocalTime(17, 42),
    ));
  });

  test(
    'turns a local date and time in the place time zone into an instant',
    () {
      expect(
        zonedInstant(
          LocalDate(2026, 10, 21),
          const LocalTime(12, 42),
          'Asia/Seoul',
        ),
        DateTime.utc(2026, 10, 21, 3, 42),
      );
      expect(
        zonedInstant(
          LocalDate(2026, 12, 1),
          const LocalTime(9, 0),
          'Europe/Paris',
        ),
        DateTime.utc(2026, 12, 1, 8),
      );
    },
  );

  test('round-trips through the place time zone', () {
    final instant = DateTime.utc(2026, 10, 21, 15, 5);
    final parts = zonedParts(instant, 'Asia/Seoul');
    expect(zonedInstant(parts.date, parts.time, 'Asia/Seoul'), instant);
  });

  test('falls back to the device time zone for an unknown name', () {
    final instant = DateTime.utc(2026, 10, 21, 3, 42);
    final local = instant.toLocal();
    expect(zonedParts(instant, 'Mars/Olympus').time.hour, local.hour);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';

void main() {
  test('keeps only the calendar date of a DateTime', () {
    expect(
      LocalDate.fromDateTime(DateTime(2026, 10, 15, 23, 59)),
      LocalDate(2026, 10, 15),
    );
  });

  test('rolls overflowing days into the next month', () {
    expect(LocalDate(2026, 1, 32), LocalDate(2026, 2, 1));
  });

  test('adds days across months and years', () {
    expect(LocalDate(2026, 12, 30).addDays(3), LocalDate(2027, 1, 2));
    expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
    expect(LocalDate(2028, 3, 1).addDays(-1), LocalDate(2028, 2, 29));
  });

  test('counts days between dates', () {
    expect(LocalDate(2026, 10, 15).daysUntil(LocalDate(2026, 10, 17)), 2);
    expect(LocalDate(2026, 12, 31).daysUntil(LocalDate(2027, 1, 1)), 1);
    expect(LocalDate(2028, 2, 28).daysUntil(LocalDate(2028, 3, 1)), 2);
    expect(LocalDate(2026, 10, 17).daysUntil(LocalDate(2026, 10, 15)), -2);
  });

  test('compares dates', () {
    final a = LocalDate(2026, 10, 15);
    final b = LocalDate(2026, 10, 16);

    expect(a.isBefore(b), isTrue);
    expect(b.isAfter(a), isTrue);
    expect(a.isBefore(a), isFalse);
    expect(a, LocalDate(2026, 10, 15));
  });

  test('prints as ISO 8601', () {
    expect(LocalDate(2026, 1, 5).toString(), '2026-01-05');
  });
}

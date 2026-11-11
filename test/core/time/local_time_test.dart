import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_time.dart';

void main() {
  test('prints as hours and minutes', () {
    expect(const LocalTime(9, 5).toString(), '09:05');
  });

  test('parses what it prints', () {
    expect(LocalTime.parse('09:05'), const LocalTime(9, 5));
    expect(LocalTime.parse('23:59'), const LocalTime(23, 59));
  });

  test('refuses times out of range or in another format', () {
    for (final text in ['24:00', '09:60', '9:05', '09:05:00', '', 'x']) {
      expect(() => LocalTime.parse(text), throwsFormatException, reason: text);
    }
  });
}

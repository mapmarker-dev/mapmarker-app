import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/time_wheel_sheet.dart';

void main() {
  group('roundToMinuteStep', () {
    test('keeps times already on 5 minutes', () {
      expect(roundToMinuteStep(const LocalTime(9, 30)), const LocalTime(9, 30));
      expect(roundToMinuteStep(const LocalTime(0, 0)), const LocalTime(0, 0));
    });

    test('rounds to the nearest 5 minutes', () {
      expect(roundToMinuteStep(const LocalTime(9, 32)), const LocalTime(9, 30));
      expect(roundToMinuteStep(const LocalTime(9, 33)), const LocalTime(9, 35));
      expect(roundToMinuteStep(const LocalTime(9, 58)), const LocalTime(10, 0));
    });

    test('does not run into the next day', () {
      expect(
        roundToMinuteStep(const LocalTime(23, 58)),
        const LocalTime(23, 55),
      );
    });
  });
}

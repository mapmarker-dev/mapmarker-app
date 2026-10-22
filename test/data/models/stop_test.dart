import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_time.dart';

import '../../helpers/test_stops.dart';

void main() {
  group('copyWith', () {
    final stop = testStop(
      'a',
    ).copyWith(plannedTime: () => const LocalTime(9, 0));

    test('keeps the planned time unless given', () {
      expect(stop.plannedTime, const LocalTime(9, 0));
      expect(stop.copyWith(name: 'b').plannedTime, const LocalTime(9, 0));
    });

    test('changes or clears the planned time', () {
      expect(
        stop.copyWith(plannedTime: () => const LocalTime(18, 30)).plannedTime,
        const LocalTime(18, 30),
      );
      expect(stop.copyWith(plannedTime: () => null).plannedTime, isNull);
    });
  });
}

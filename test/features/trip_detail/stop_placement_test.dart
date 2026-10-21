import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/features/trip_detail/stop_placement.dart';

import '../../helpers/test_stops.dart';

void main() {
  group('insertionOrder', () {
    test('puts a stop at the end of the day', () {
      expect(insertionOrder([], StopKind.other), 0);
      expect(insertionOrder([testStop('a'), testStop('b')], StopKind.food), 2);
    });

    test('keeps the lodging of the night last', () {
      final day = [testStop('a'), testLodging('hotel', order: 1)];

      expect(insertionOrder(day, StopKind.tour), 1);
      expect(insertionOrder([testLodging('hotel')], StopKind.other), 0);
    });

    test('puts new lodging at the very end', () {
      final day = [testStop('a'), testLodging('hotel', order: 1)];

      expect(insertionOrder(day, StopKind.lodging), 2);
    });
  });

  group('defaultDayForNewStop', () {
    test('uses the day being viewed', () {
      final route = TripRoute(stops: [testStop('a', day: 2)]);

      expect(defaultDayForNewStop(route, viewDay: 1), 1);
    });

    test('continues the last day with stops in the whole trip', () {
      final route = TripRoute(
        stops: [testStop('a'), testStop('b', day: 3), testStop('c', day: 2)],
      );

      expect(defaultDayForNewStop(route), 3);
    });

    test('starts from day 1 in an empty trip', () {
      expect(defaultDayForNewStop(TripRoute()), 1);
    });
  });

  test('stays another night with the name, place and notes', () {
    final hotel = testLodging(
      'hotel',
      day: 1,
      order: 3,
    ).copyWith(description: '바다 전망', memo: '현관 비밀번호 1234');

    final again = stayAnotherNight(hotel, id: 'hotel-2', day: 2, order: 4);

    expect(again.id, 'hotel-2');
    expect((again.day, again.order), (2, 4));
    expect(again.isSamePlaceAs(hotel), isTrue);
    expect(again.name, hotel.name);
    expect(again.kind, StopKind.lodging);
    expect(again.description, '바다 전망');
    // 메모는 두 밤 모두 필요해서 복사한다(사용자 결정).
    expect(again.memo, '현관 비밀번호 1234');
    expect(again.plannedTime, isNull);
  });
}

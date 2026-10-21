import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/route_links.dart';
import 'package:mapmarker_app/features/trip_detail/day_itinerary.dart';

import '../../helpers/test_stops.dart';

TripRoute _route(List<Stop> stops) {
  final ordered = TripRoute(stops: stops).stops;
  return TripRoute(
    stops: ordered,
    segments: linkStops(tripId: 'trip', stops: ordered, existing: const []),
  );
}

/// 구간이 잇는 장소. 예: `hotel>c`.
String _link(TripRoute route, ItineraryStop entry) {
  final arrival = entry.arrival!;
  return '${route.stopById(arrival.fromStopId)!.id}>${entry.stop.id}';
}

void main() {
  // 1일차: a > 숙소, 2일차: c > 낮에 들른 숙소 > d > 숙소(연박, 같은 자리)
  final route = _route([
    testStop('a'),
    testLodging('hotel', order: 1),
    testStop('c', day: 2),
    testStop('nap', day: 2, order: 1, kind: StopKind.lodging),
    testStop('d', day: 2, order: 2, kind: StopKind.food),
    testLodging('hotel2', day: 2, order: 3),
  ]);

  group('DayItinerary', () {
    test('starts from the lodging of the night before', () {
      final day2 = DayItinerary.of(route, route.view(day: 2), 2);

      expect(day2.start?.id, 'hotel');
      expect(day2.stops.map((s) => s.stop.id), ['c', 'nap', 'd', 'hotel2']);
      expect(day2.stops.map((s) => s.number), [1, null, 2, null]);
      expect(day2.stops.map((s) => _link(route, s)), [
        'hotel>c',
        'c>nap',
        'nap>d',
        'd>hotel2',
      ]);
      expect(day2.stopIds, ['hotel', 'c', 'nap', 'd', 'hotel2']);
    });

    test('has no way in on the first day', () {
      final day1 = DayItinerary.of(route, route.view(day: 1), 1);

      expect(day1.start, isNull);
      expect(day1.stops.first.arrival, isNull);
      expect(_link(route, day1.stops.last), 'a>hotel');
    });

    test('follows the map when lodging is hidden', () {
      final day2 = DayItinerary.of(
        route,
        route.view(day: 2, showLodging: false),
        2,
      );

      expect(day2.start, isNull);
      expect(day2.stops.map((s) => s.stop.id), ['c', 'd']);
      // 숨은 숙소를 거치는 길은 지도처럼 끊긴다.
      expect(day2.stops.map((s) => s.arrival), [null, null]);
    });

    test('offers to stay another night until the night has lodging', () {
      // 1일차: a > 숙소, 2일차: c, 3일차: 없음.
      final trip = _route([
        testStop('a'),
        testLodging('hotel', order: 1),
        testStop('c', day: 2),
      ]);
      DayItinerary dayOf(TripRoute route, int day, {bool lodging = true}) =>
          DayItinerary.of(
            route,
            route.view(day: day, showLodging: lodging),
            day,
          );

      // 전날 숙소가 없다.
      expect(dayOf(trip, 1).lodgingToStayAgain, isNull);
      expect(dayOf(trip, 2).lodgingToStayAgain?.id, 'hotel');
      // 2일차 밤 숙소가 없어서 3일차는 숙소에서 출발하지 않는다.
      expect(dayOf(trip, 3).lodgingToStayAgain, isNull);
      // 숙소를 끄면 출발 숙소도 보이지 않는다.
      expect(dayOf(trip, 2, lodging: false).lodgingToStayAgain, isNull);
      // 그날 밤 숙소가 있다.
      expect(dayOf(route, 2).lodgingToStayAgain, isNull);
    });

    test('knows its stops and segments', () {
      final day2 = DayItinerary.of(route, route.view(day: 2), 2);

      expect(day2.contains('hotel'), isTrue);
      expect(day2.contains('d'), isTrue);
      expect(day2.contains(day2.stops.first.arrival!.id), isTrue);
      expect(day2.contains('a'), isFalse);
    });
  });

  group('reorderedStopOrder', () {
    final dayStops = route.stops.where((s) => s.day == 2).toList();

    int orderAfter(List<String> visibleIds, int oldIndex, int newIndex) =>
        reorderedStopOrder(
          visibleIds: visibleIds,
          dayStops: dayStops,
          oldIndex: oldIndex,
          newIndex: newIndex,
        );

    test('uses the sheet position when everything is visible', () {
      final ids = ['c', 'nap', 'd', 'hotel2'];

      expect(orderAfter(ids, 2, 0), 0);
      expect(orderAfter(ids, 0, 2), 2);
      expect(orderAfter(ids, 0, 3), 3);
    });

    test('puts the stop after the one before it when lodging is hidden', () {
      // 시트에는 c, d만 보인다. 전체는 c, nap, d, hotel2다.
      final ids = ['c', 'd'];

      // d를 맨 앞으로: c 앞.
      expect(orderAfter(ids, 1, 0), 0);
      // c를 d 뒤로: 숨은 그날 밤 숙소(hotel2) 앞에 남는다.
      expect(orderAfter(ids, 0, 1), 2);
    });
  });
}

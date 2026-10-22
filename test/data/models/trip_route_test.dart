import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/route_links.dart';

import '../../helpers/test_stops.dart';

/// 구간을 저장소처럼 이웃한 장소 사이에 이은 동선.
TripRoute _route(List<Stop> stops) {
  final ordered = TripRoute(stops: stops).stops;
  return TripRoute(
    stops: ordered,
    segments: linkStops(tripId: 'trip', stops: ordered, existing: const []),
  );
}

List<String> _ids(RouteView view) => [for (final s in view.stops) s.id];

List<String> _lines(TripRoute route, RouteView view) => [
  for (final s in view.segments)
    '${route.stopById(s.fromStopId)!.id}>${route.stopById(s.toStopId)!.id}',
];

void main() {
  // 1일차: 숙소 > 1 > 2 > 3 > 4 > 숙소A
  // 2일차: 5 > 6 > 7 > 8 > 숙소A(연박)
  // 3일차: 9 > 숙소B(숙소를 옮김)
  // 4일차: 10
  final route = _route([
    testLodging('start', day: 1, order: 0),
    for (var i = 1; i <= 4; i++) testStop('p$i', day: 1, order: i),
    testLodging('hotelA', day: 1, order: 5),
    for (var i = 5; i <= 8; i++) testStop('p$i', day: 2, order: i - 5),
    testLodging('hotelA2', day: 2, order: 4),
    testStop('p9', day: 3, order: 0, kind: StopKind.food),
    testStop(
      'hotelB',
      day: 3,
      order: 1,
      kind: StopKind.lodging,
      latitude: 35.2,
      longitude: 129.2,
    ),
    testStop('p10', day: 4, order: 0),
  ]);

  test('keeps stops in day and order', () {
    final shuffled = TripRoute(
      stops: [
        testStop('c', day: 2, order: 0),
        testStop('b', day: 1, order: 1),
        testStop('a', day: 1, order: 0),
      ],
    );

    expect(shuffled.stops.map((s) => s.id), ['a', 'b', 'c']);
  });

  test('numbers places from 1 each day and leaves lodging out', () {
    String number(String id) => '${route.numberOf(route.stopById(id)!)}';

    expect(['p1', 'p2', 'p3', 'p4'].map(number), ['1', '2', '3', '4']);
    expect(['p5', 'p6', 'p7', 'p8'].map(number), ['1', '2', '3', '4']);
    expect(number('p9'), '1');
    expect(number('start'), 'null');
    expect(number('hotelA'), 'null');
  });

  group('whole trip', () {
    test('shows every stop as one route', () {
      final view = route.view();

      expect(_ids(view), route.stops.map((s) => s.id));
      expect(view.segments, hasLength(route.stops.length - 1));
      expect(_lines(route, view), contains('hotelA>p5'));
    });

    test('drops lodging and its segments when lodging is off', () {
      final view = route.view(showLodging: false);

      expect(_ids(view), [for (var i = 1; i <= 10; i++) 'p$i']);
      expect(_lines(route, view), [
        'p1>p2',
        'p2>p3',
        'p3>p4',
        'p5>p6',
        'p6>p7',
        'p7>p8',
      ]);
    });
  });

  group('one day', () {
    test('day 1 with lodging', () {
      final view = route.view(day: 1);

      expect(_ids(view), ['start', 'p1', 'p2', 'p3', 'p4', 'hotelA']);
      expect(_lines(route, view), [
        'start>p1',
        'p1>p2',
        'p2>p3',
        'p3>p4',
        'p4>hotelA',
      ]);
    });

    test('day 1 without lodging', () {
      final view = route.view(day: 1, showLodging: false);

      expect(_ids(view), ['p1', 'p2', 'p3', 'p4']);
      expect(_lines(route, view), ['p1>p2', 'p2>p3', 'p3>p4']);
    });

    test('day 2 starts from the lodging of the night before', () {
      final view = route.view(day: 2);

      expect(_ids(view), ['hotelA', 'p5', 'p6', 'p7', 'p8', 'hotelA2']);
      expect(_lines(route, view).first, 'hotelA>p5');
    });

    test('day 2 without lodging', () {
      final view = route.view(day: 2, showLodging: false);

      expect(_ids(view), ['p5', 'p6', 'p7', 'p8']);
      expect(_lines(route, view), ['p5>p6', 'p6>p7', 'p7>p8']);
    });

    test('follows a change of lodging', () {
      expect(_ids(route.view(day: 3)), ['hotelA2', 'p9', 'hotelB']);
      expect(_ids(route.view(day: 4)), ['hotelB', 'p10']);
      expect(_lines(route, route.view(day: 4)), ['hotelB>p10']);
    });
  });

  test('a day without stops still shows where it starts', () {
    final withEmptyDay = _route([
      testStop('a', day: 1),
      testLodging('hotel', day: 1, order: 1),
      testStop('b', day: 3),
    ]);

    expect(_ids(withEmptyDay.view(day: 2)), ['hotel']);
    expect(withEmptyDay.view(day: 2).segments, isEmpty);
    expect(withEmptyDay.view(day: 2, showLodging: false).stops, isEmpty);
    // 앞 일차의 마지막 장소가 숙소라서 3일차도 그 숙소에서 출발한다.
    expect(_ids(withEmptyDay.view(day: 3)), ['hotel', 'b']);
  });

  test('starts from the last place of the day before, lodging or not', () {
    // 1일차가 공항에서 끝난다(야간 비행기 등). 일차를 넘는 구간이 2일차 보기에 보인다.
    final noLodging = _route([testStop('airport'), testStop('b', day: 2)]);

    expect(noLodging.startOf(2)?.id, 'airport');
    expect(_ids(noLodging.view(day: 2)), ['airport', 'b']);
    expect(_lines(noLodging, noLodging.view(day: 2)), ['airport>b']);
    // 숙소를 꺼도 숙소가 아닌 출발 장소는 남는다.
    expect(_ids(noLodging.view(day: 2, showLodging: false)), ['airport', 'b']);
  });

  test('does not repeat a place the day already starts at', () {
    // 전날 마지막 장소 T를 다음 날 첫 장소로 또 넣었다.
    final same = _route([
      testStop('t', latitude: 35.2, longitude: 129.2),
      testStop('t-again', day: 2, latitude: 35.2, longitude: 129.2),
      testStop('b', day: 2, order: 1),
    ]);

    expect(same.startOf(2), isNull);
    expect(_ids(same.view(day: 2)), ['t-again', 'b']);
  });

  test('does not repeat the lodging when the day already starts there', () {
    final repeated = _route([
      testStop('a'),
      testLodging('hotel1', order: 1),
      testLodging('hotel2', day: 2),
      testStop('b', day: 2, order: 1),
    ]);

    expect(repeated.startOf(2), isNull);
    expect(_ids(repeated.view(day: 2)), ['hotel2', 'b']);
  });

  test('the first day has no lodging before it', () {
    expect(route.startOf(1), isNull);
    expect(TripRoute().view(day: 1).stops, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/trips/route_links.dart';

import '../../helpers/test_stops.dart';

void main() {
  var count = 0;
  String createId() => 'new${count++}';

  setUp(() => count = 0);

  List<(String, String)> pairs(List<Segment> segments) => [
    for (final s in segments) (s.fromStopId, s.toStopId),
  ];

  test('links each pair of neighbors, across days too', () {
    final segments = linkStops(
      tripId: 'trip',
      stops: [
        testStop('a'),
        testStop('b', order: 1),
        testLodging('hotel', order: 2),
        testStop('c', day: 2),
      ],
      existing: const [],
      createId: createId,
    );

    expect(pairs(segments), [('a', 'b'), ('b', 'hotel'), ('hotel', 'c')]);
    expect(segments.every((s) => s.tripId == 'trip'), isTrue);
    expect(segments.every((s) => s.legs.isEmpty && s.curvature == 0), isTrue);
  });

  test('keeps segments whose stops are still neighbors', () {
    const kept = Segment(
      id: 'ab',
      tripId: 'trip',
      fromStopId: 'a',
      toStopId: 'b',
      legs: [TransportLeg(TransportMode.subway, stopCount: 2)],
      curvature: 0.3,
    );

    final segments = linkStops(
      tripId: 'trip',
      stops: [testStop('a'), testStop('b', order: 1), testStop('c', order: 2)],
      existing: [kept],
      createId: createId,
    );

    expect(segments.first, same(kept));
    expect(segments.last.id, 'new0');
  });

  test('drops segments whose stops are no longer neighbors', () {
    final segments = linkStops(
      tripId: 'trip',
      stops: [testStop('a'), testStop('x', order: 1), testStop('b', order: 2)],
      existing: const [
        Segment(id: 'ab', tripId: 'trip', fromStopId: 'a', toStopId: 'b'),
      ],
      createId: createId,
    );

    expect(pairs(segments), [('a', 'x'), ('x', 'b')]);
    expect(segments.map((s) => s.id), isNot(contains('ab')));
  });

  test('needs two stops for a segment', () {
    expect(
      linkStops(tripId: 'trip', stops: [testStop('a')], existing: const []),
      isEmpty,
    );
  });

  group('segments dropped by a move', () {
    // 1일차: a > b > c, 2일차: d.
    final stops = [
      testStop('a'),
      testStop('b', order: 1),
      testStop('c', order: 2),
      testStop('d', day: 2),
    ];
    final segments = linkStops(
      tripId: 'trip',
      stops: stops,
      existing: const [],
      createId: createId,
    );

    List<(String, String)> dropped(String stopId, int day, int order) => pairs(
      segmentsDroppedByMove(
        stops: stops,
        segments: segments,
        stopId: stopId,
        day: day,
        order: order,
      ),
    );

    test('are the ones into and out of the stop, and the gap it fills', () {
      // a를 b와 c 사이로: a>b, b>c가 사라지고 b>a, a>c가 생긴다.
      expect(dropped('a', 1, 1), [('a', 'b'), ('b', 'c')]);
    });

    test('include the link across days when moving to the end', () {
      // a를 1일차 맨 뒤로: c>d 사이에 끼어든다.
      expect(dropped('a', 1, 5), [('a', 'b'), ('c', 'd')]);
    });

    test('include segments of another day', () {
      // d를 1일차 맨 앞으로.
      expect(dropped('d', 1, 0), [('c', 'd')]);
      expect(dropped('b', 2, 0), [('a', 'b'), ('b', 'c'), ('c', 'd')]);
    });

    test('are none when the stop stays where it is', () {
      expect(dropped('b', 1, 1), isEmpty);
    });

    test('are none for an unknown stop', () {
      expect(dropped('x', 1, 0), isEmpty);
    });
  });
}

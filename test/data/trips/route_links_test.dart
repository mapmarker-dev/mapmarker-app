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
}

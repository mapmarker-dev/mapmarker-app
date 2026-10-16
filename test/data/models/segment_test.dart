import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/segment.dart';

// 이동 수단의 화면 글자는 test/l10n/model_texts_test.dart에서 본다.
void main() {
  test('starts straight with no transport chosen', () {
    const segment = Segment(
      id: 'segment-1',
      tripId: 'trip-1',
      fromStopId: 'stop-1',
      toStopId: 'stop-2',
    );

    expect(segment.curvature, 0);
    expect(segment.type, SegmentType.normal);
    expect(segment.legs, isEmpty);
  });

  test('compares legs by mode, stops and duration', () {
    expect(
      const TransportLeg(TransportMode.subway, stopCount: 2),
      const TransportLeg(TransportMode.subway, stopCount: 2),
    );
    expect(
      const TransportLeg(TransportMode.subway, stopCount: 2),
      isNot(const TransportLeg(TransportMode.bus, stopCount: 2)),
    );
  });
}

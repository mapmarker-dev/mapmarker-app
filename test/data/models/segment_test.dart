import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/segment.dart';

Segment _segment(List<TransportLeg> legs) => Segment(
  id: 'segment-1',
  tripId: 'trip-1',
  fromStopId: 'stop-1',
  toStopId: 'stop-2',
  legs: legs,
);

void main() {
  test('labels a leg with stops or duration', () {
    expect(
      const TransportLeg(TransportMode.subway, stopCount: 4).label,
      '지하철 4정류장',
    );
    expect(
      const TransportLeg(TransportMode.bus, stopCount: 3).label,
      '버스 3정류장',
    );
    expect(
      const TransportLeg(
        TransportMode.walk,
        duration: Duration(minutes: 20),
      ).label,
      '도보 20분',
    );
    expect(
      const TransportLeg(
        TransportMode.flight,
        duration: Duration(hours: 3, minutes: 20),
      ).label,
      '비행기 3시간 20분',
    );
    expect(
      const TransportLeg(
        TransportMode.ferry,
        duration: Duration(hours: 1, minutes: 40),
      ).label,
      '배 1시간 40분',
    );
    expect(
      const TransportLeg(
        TransportMode.train,
        duration: Duration(hours: 2),
      ).label,
      '기차 2시간',
    );
  });

  test('labels a mode alone when nothing else is known', () {
    expect(const TransportLeg(TransportMode.walk).label, '도보');
  });

  test('joins transfers with +', () {
    expect(
      _segment(const [
        TransportLeg(TransportMode.subway, stopCount: 2),
        TransportLeg(TransportMode.walk),
      ]).transportLabel,
      '지하철 2정류장 + 도보',
    );
    expect(
      _segment(const [
        TransportLeg(TransportMode.bus, stopCount: 1),
        TransportLeg(TransportMode.walk),
      ]).transportLabel,
      '버스 1정류장 + 도보',
    );
  });

  test('starts straight with no transport chosen', () {
    final segment = _segment(const []);

    expect(segment.curvature, 0);
    expect(segment.type, SegmentType.normal);
    expect(segment.transportLabel, isEmpty);
  });
}

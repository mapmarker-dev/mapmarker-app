import 'package:flutter/foundation.dart';

/// 이동 수단. 화면 글자는 `l10n/model_texts.dart`에 있다.
enum TransportMode { walk, subway, bus, train, car, flight, ferry }

/// 이동 한 토막. 예: 지하철 4정류장, 도보 20분, 비행기 3시간 20분.
@immutable
class TransportLeg {
  const TransportLeg(this.mode, {this.stopCount, this.duration});

  final TransportMode mode;

  /// 지나는 정류장 수. 지하철·버스처럼 정류장을 세는 수단에 쓴다.
  final int? stopCount;

  /// 걸리는 시간.
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is TransportLeg &&
      other.mode == mode &&
      other.stopCount == stopCount &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(mode, stopCount, duration);

  @override
  String toString() => 'TransportLeg($mode, $stopCount, $duration)';
}

/// 구간 종류. 직선과 곡선은 [Segment.curvature]로 나뉘고, 그리는 방식이 다른 GPS 트랙만 따로 둔다.
enum SegmentType { normal, gpsTrack }

/// 구간. 장소 A에서 장소 B로 가는 길이다. 실제 도로 경로는 그리지 않고 직선·곡선으로 그린다.
@immutable
class Segment {
  const Segment({
    required this.id,
    required this.tripId,
    required this.fromStopId,
    required this.toStopId,
    this.legs = const [],
    this.curvature = 0,
    this.type = SegmentType.normal,
  });

  final String id;
  final String tripId;
  final String fromStopId;
  final String toStopId;

  /// 이동 수단. 갈아타면 여러 토막이다. 예: 지하철 2정류장 + 도보.
  /// 비어 있으면 아직 정하지 않은 것이다.
  final List<TransportLeg> legs;

  /// 곡률 k. 0이면 직선이고, 부호에 따라 휘는 방향이 바뀐다.
  final double curvature;

  final SegmentType type;
}

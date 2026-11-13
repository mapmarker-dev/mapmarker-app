import 'package:flutter/foundation.dart';

import '../../core/map/geo.dart';
import 'map_provider_type.dart';
import 'stop.dart';

/// 후보 장소. 갈지 말지 정하지 않은 곳을 여행마다 모아 둔다.
///
/// 장소([Stop])와 달리 일차·순서·예정 시각·방문·사진이 없고, 동선(구간)에 들지 않는다.
/// [동선에 넣기]로 같은 ID의 장소가 되고, 장소를 [후보로 빼기]하면 같은 ID의 후보가 된다.
/// 여행 안에서는 넣은 순서로 보여 준다(후보로 뺀 장소는 맨 뒤).
@immutable
class Candidate {
  const Candidate({
    required this.id,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.name,
    this.kind = StopKind.other,
    this.description = '',
    this.memo = '',
    this.placeProvider,
    this.placeId,
  });

  final String id;
  final String tripId;
  final double latitude;
  final double longitude;
  final String name;
  final StopKind kind;

  /// 사용자가 직접 쓴 설명. 공유하면 보인다.
  final String description;

  /// 작성자의 개인 기록. 공유하면 숨긴다.
  final String memo;

  /// [placeId]를 준 서비스.
  final MapProviderType? placeProvider;

  final String? placeId;

  LatLng get position => LatLng(latitude, longitude);

  Candidate copyWith({
    String? name,
    StopKind? kind,
    String? description,
    String? memo,
  }) => Candidate(
    id: id,
    tripId: tripId,
    latitude: latitude,
    longitude: longitude,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    memo: memo ?? this.memo,
    placeProvider: placeProvider,
    placeId: placeId,
  );

  /// 후보로 뺀 장소. 일차·순서·예정 시각·방문·시간대는 버린다(서버의 후보로 빼기와 같다).
  factory Candidate.fromStop(Stop stop) => Candidate(
    id: stop.id,
    tripId: stop.tripId,
    latitude: stop.latitude,
    longitude: stop.longitude,
    name: stop.name,
    kind: stop.kind,
    description: stop.description,
    memo: stop.memo,
    placeProvider: stop.placeProvider,
    placeId: stop.placeId,
  );

  @override
  bool operator ==(Object other) =>
      other is Candidate &&
      other.id == id &&
      other.tripId == tripId &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.name == name &&
      other.kind == kind &&
      other.description == description &&
      other.memo == memo &&
      other.placeProvider == placeProvider &&
      other.placeId == placeId;

  @override
  int get hashCode => Object.hash(
    id,
    tripId,
    latitude,
    longitude,
    name,
    kind,
    description,
    memo,
    placeProvider,
    placeId,
  );

  @override
  String toString() => 'Candidate($id, $name)';
}

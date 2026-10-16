import 'package:mapmarker_app/data/models/stop.dart';

/// 테스트용 장소. 좌표를 따로 주지 않으면 [id]마다 서로 다른 자리에 놓는다.
Stop testStop(
  String id, {
  String tripId = 'trip',
  int day = 1,
  int order = 0,
  StopKind kind = StopKind.other,
  double? latitude,
  double? longitude,
}) {
  final spread = id.codeUnits.fold(0, (h, c) => (h * 31 + c) % 1000) / 10000;
  return Stop(
    id: id,
    tripId: tripId,
    latitude: latitude ?? 35.1 + spread,
    longitude: longitude ?? 129.0 + spread,
    name: id,
    day: day,
    order: order,
    kind: kind,
  );
}

/// 같은 자리의 숙소. 연박하면 밤마다 넣는다.
Stop testLodging(
  String id, {
  String tripId = 'trip',
  int day = 1,
  int order = 0,
}) => testStop(
  id,
  tripId: tripId,
  day: day,
  order: order,
  kind: StopKind.lodging,
  latitude: 35.16,
  longitude: 129.16,
);

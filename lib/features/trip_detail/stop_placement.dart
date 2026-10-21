import '../../data/models/stop.dart';
import '../../data/models/trip_route.dart';

/// 새로 넣거나 다른 일차로 옮긴 장소가 들어갈 일차 안 순서([Stop.order]).
///
/// 그 일차의 맨 뒤다. 다만 마지막이 숙소면 숙소 바로 앞이다.
/// 숙소는 그날 밤 묵는 곳이라 일차 마지막에 남아야 다음 날 보기가 그 숙소에서 출발한다.
/// 넣는 장소가 숙소면 맨 뒤다.
///
/// [dayStops]는 넣을 일차의 장소다(동선 순서, 옮기는 장소는 빼고).
int insertionOrder(List<Stop> dayStops, StopKind kind) {
  if (kind == StopKind.lodging) return dayStops.length;
  if (dayStops.lastOrNull?.isLodging ?? false) return dayStops.length - 1;
  return dayStops.length;
}

/// 장소를 추가할 때 처음 고를 일차.
///
/// 일차 보기면 그 일차다. 전체 보기면 장소가 있는 마지막 일차이고, 장소가 없으면 1일차다.
/// 계획은 보통 앞에서부터 채워 가서, 마지막으로 채우던 일차에 이어 넣을 가능성이 크다.
int defaultDayForNewStop(TripRoute route, {int? viewDay}) =>
    viewDay ?? route.stops.lastOrNull?.day ?? 1;

/// 연박: 전날 밤 숙소를 [day]일차 밤에도 묵는 숙소로 복사한다. 그 일차 맨 뒤에 넣을 장소다.
///
/// 같은 자리라 지도에서는 마커 하나로 합쳐진다. 메모(체크인 시각, 현관 비밀번호 등)도 두 밤에 다 필요해서 복사한다.
/// 예정 시각과 방문 기록은 그날 것이라 복사하지 않는다.
Stop stayAnotherNight(
  Stop lodging, {
  required String id,
  required int day,
  required int order,
}) => Stop(
  id: id,
  tripId: lodging.tripId,
  latitude: lodging.latitude,
  longitude: lodging.longitude,
  name: lodging.name,
  kind: lodging.kind,
  day: day,
  order: order,
  description: lodging.description,
  memo: lodging.memo,
  timeZone: lodging.timeZone,
  placeProvider: lodging.placeProvider,
  placeId: lodging.placeId,
);

import 'package:flutter/foundation.dart';

import '../../core/map/geo.dart';
import '../../core/time/local_time.dart';
import 'map_provider_type.dart';

/// 장소 종류. 화면 글자는 `l10n/model_texts.dart`에 있다.
///
/// 숙소만 동선 규칙이 있다(그날 밤 묵는 곳으로 일차 마지막에 둠, 숙소 끄기, 연박). 나머지는 지도에 아이콘으로만 보여 준다.
enum StopKind {
  lodging,

  /// 식당, 카페, 술집.
  food,

  /// 명소, 자연, 전시, 체험.
  tour,

  /// 고르지 않았거나 어디에도 맞지 않는 장소. 기본값이다.
  other,
}

/// 장소. 지도에 찍는 점이다.
///
/// 예정 시각은 날짜 없이 일차 + 현지 시각으로 담는다.
/// 날짜는 여행 시작일 + (일차 − 1)이라서, 기간이 없는 여행에도 넣을 수 있고, 여행 날짜를 옮기거나 다른 사람이 복사해도 적용된다.
@immutable
class Stop {
  const Stop({
    required this.id,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.day,
    required this.order,
    this.kind = StopKind.other,
    this.description = '',
    this.memo = '',
    this.plannedTime,
    this.visited = false,
    this.visitedAt,
    this.timeZone = defaultTimeZone,
    this.placeProvider,
    this.placeId,
  }) : assert(day >= 1),
       assert(order >= 0);

  /// 1단계(국내)의 시간대.
  static const defaultTimeZone = 'Asia/Seoul';

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

  /// 일차. 1일차부터 센다.
  final int day;

  /// 일차 안에서의 순서. 0부터 센다.
  final int order;

  /// 예정 시각. [timeZone] 기준 현지 시각이다.
  final LocalTime? plannedTime;

  final bool visited;

  /// 실제로 방문한 순간 (UTC). 화면에는 [timeZone] 기준 현지 시각으로 보여 준다.
  final DateTime? visitedAt;

  /// IANA 시간대 이름. 예: `Asia/Seoul`, `Europe/Paris`.
  final String timeZone;

  /// [placeId]를 준 서비스.
  final MapProviderType? placeProvider;

  final String? placeId;

  bool get isLodging => kind == StopKind.lodging;

  LatLng get position => LatLng(latitude, longitude);

  /// 좌표가 같은지. 연박할 때 밤마다 넣은 같은 숙소를 지도에서 하나로 합치는 데 쓴다.
  bool isSamePlaceAs(Stop other) =>
      other.latitude == latitude && other.longitude == longitude;

  Stop copyWith({
    double? latitude,
    double? longitude,
    String? name,
    StopKind? kind,
    int? day,
    int? order,
    String? description,
    String? memo,
    // 예정 시각은 지울 수도 있어서 함수로 받는다.
    LocalTime? Function()? plannedTime,
  }) => Stop(
    id: id,
    tripId: tripId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    day: day ?? this.day,
    order: order ?? this.order,
    description: description ?? this.description,
    memo: memo ?? this.memo,
    plannedTime: plannedTime == null ? this.plannedTime : plannedTime(),
    visited: visited,
    visitedAt: visitedAt,
    timeZone: timeZone,
    placeProvider: placeProvider,
    placeId: placeId,
  );

  @override
  String toString() => 'Stop($id, $name, day $day, order $order)';
}

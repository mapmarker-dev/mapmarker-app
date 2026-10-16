import 'package:flutter/foundation.dart';

import '../../core/time/local_time.dart';
import 'map_provider_type.dart';

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
}

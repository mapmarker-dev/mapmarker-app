import 'package:flutter/foundation.dart';

import 'trip.dart';

/// 휴지통의 여행. 장소·구간은 휴지통에 함께 있지만 되살리기 전에는 보지 않는다.
@immutable
class TrashedTrip {
  const TrashedTrip({
    required this.trip,
    required this.deletedAt,
    required this.purgeAt,
  });

  final Trip trip;

  /// 휴지통에 넣은 순간(UTC).
  final DateTime deletedAt;

  /// 완전히 지워지는 순간(UTC). 보관 기간은 서버가 정하고 이 값으로만 알린다.
  final DateTime purgeAt;
}

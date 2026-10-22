import 'package:flutter/foundation.dart';

import '../../core/map/geo.dart';
import '../../core/time/local_time.dart';
import '../../data/models/stop.dart';

/// 장소 입력 화면에서 고치는 값. 추가와 편집이 함께 쓴다. 좌표는 고치지 않는다.
@immutable
class StopDraft {
  const StopDraft({
    this.name = '',
    this.kind = StopKind.other,
    required this.day,
    this.plannedTime,
    this.description = '',
    this.memo = '',
    this.slotOrder,
  });

  factory StopDraft.of(Stop stop) => StopDraft(
    name: stop.name,
    kind: stop.kind,
    day: stop.day,
    plannedTime: stop.plannedTime,
    description: stop.description,
    memo: stop.memo,
  );

  /// 이름 최대 글자 수. 지도 마커 이름과 시트 한 줄에 들어갈 만큼이다.
  static const nameMaxLength = 50;

  /// 설명과 메모 최대 글자 수.
  static const textMaxLength = 1000;

  final String name;
  final StopKind kind;
  final int day;
  final LocalTime? plannedTime;
  final String description;
  final String memo;

  /// "넣을 자리" 칸에서 고른 일차 안 순서([Stop.order]). null이면 고르지 않은 것이라 기본 자리다
  /// (`stop_placement.dart`의 `insertionOrder`). 기본 자리는 종류에 따라 바뀌어서 저장할 때 정한다.
  final int? slotOrder;

  /// 저장할 수 있는지. 이름은 앞뒤 공백을 빼고 1자 이상이어야 한다.
  bool get isValid {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= nameMaxLength &&
        description.length <= textMaxLength &&
        memo.length <= textMaxLength;
  }

  StopDraft copyWith({
    String? name,
    StopKind? kind,
    int? day,
    LocalTime? Function()? plannedTime,
    String? description,
    String? memo,
    int? Function()? slotOrder,
  }) => StopDraft(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    day: day ?? this.day,
    plannedTime: plannedTime == null ? this.plannedTime : plannedTime(),
    description: description ?? this.description,
    memo: memo ?? this.memo,
    slotOrder: slotOrder == null ? this.slotOrder : slotOrder(),
  );

  /// 새 장소. 일차 안 순서는 [order]다.
  Stop toNewStop({
    required String id,
    required String tripId,
    required LatLng position,
    required int order,
  }) => Stop(
    id: id,
    tripId: tripId,
    latitude: position.latitude,
    longitude: position.longitude,
    name: name.trim(),
    kind: kind,
    day: day,
    order: order,
    plannedTime: plannedTime,
    description: description.trim(),
    memo: memo.trim(),
  );

  /// [stop]에 고친 값을 넣는다. 일차는 바꾸지 않는다(옮기기는 저장소의 `moveStop`이다).
  Stop applyTo(Stop stop) => stop.copyWith(
    name: name.trim(),
    kind: kind,
    plannedTime: () => plannedTime,
    description: description.trim(),
    memo: memo.trim(),
  );

  @override
  bool operator ==(Object other) =>
      other is StopDraft &&
      other.name == name &&
      other.kind == kind &&
      other.day == day &&
      other.plannedTime == plannedTime &&
      other.description == description &&
      other.memo == memo &&
      other.slotOrder == slotOrder;

  @override
  int get hashCode =>
      Object.hash(name, kind, day, plannedTime, description, memo, slotOrder);
}

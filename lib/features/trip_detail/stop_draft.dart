import 'package:flutter/foundation.dart';

import '../../core/map/geo.dart';
import '../../core/time/local_time.dart';
import '../../data/addresses/address_api.dart';
import '../../data/models/stop.dart';
import '../../data/photos/photo_upload.dart';

/// 장소 입력 화면에서 고치는 값. 추가와 편집이 함께 쓴다.
/// 좌표는 [relocatedTo]로만 바꾼다(주소 칸의 글자만 고치면 지도의 자리는 그대로다).
@immutable
class StopDraft {
  const StopDraft({
    this.name = '',
    this.kind = StopKind.other,
    required this.day,
    this.plannedTime,
    this.description = '',
    this.memo = '',
    this.address = '',
    this.relocatedTo,
    this.slotOrder,
    this.newPhoto,
    this.removePhoto = false,
  });

  factory StopDraft.of(Stop stop) => StopDraft(
    name: stop.name,
    kind: stop.kind,
    day: stop.day,
    plannedTime: stop.plannedTime,
    description: stop.description,
    memo: stop.memo,
    address: stop.address,
  );

  /// 이름 최대 글자 수. 지도 마커 이름과 시트 한 줄에 들어갈 만큼이다.
  static const nameMaxLength = 50;

  /// 설명과 메모 최대 글자 수.
  static const textMaxLength = 1000;

  /// 주소 최대 글자 수. 서버의 ADDRESS_MAX_LENGTH와 같다.
  static const addressMaxLength = AddressCandidate.maxLength;

  final String name;
  final StopKind kind;
  final int day;
  final LocalTime? plannedTime;
  final String description;
  final String memo;

  /// 주소. 비어 있어도 된다. 좌표와 따로 고친다.
  final String address;

  /// [주소로 위치 다시 찾기]로 고른 새 좌표. 저장하면 장소가 여기로 옮겨진다. null이면 그대로다.
  final LatLng? relocatedTo;

  /// ⊕로 정한 일차 안 순서([Stop.order]). null이면 기본 자리다
  /// (`stop_placement.dart`의 `insertionOrder`). 기본 자리는 종류에 따라 바뀌어서 저장할 때 정한다.
  final int? slotOrder;

  /// 새로 고른 사진(줄여 둔 것). 저장하면 올려서 있던 사진과 바꾼다.
  final PreparedPhoto? newPhoto;

  /// 있던 사진을 지운다. [newPhoto]가 있으면 무시한다(바꾸기다).
  final bool removePhoto;

  /// 사진을 바꾸거나 지우는지.
  bool get changesPhoto => newPhoto != null || removePhoto;

  /// 사진을 뺀 나머지 값이 [other]와 같은지. 사진만 바꿨으면 장소는 다시 저장하지 않는다.
  bool sameFieldsAs(StopDraft other) =>
      copyWith(newPhoto: () => null, removePhoto: false) ==
      other.copyWith(newPhoto: () => null, removePhoto: false);

  /// 저장할 수 있는지. 이름은 앞뒤 공백을 빼고 1자 이상이어야 한다.
  bool get isValid {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= nameMaxLength &&
        description.length <= textMaxLength &&
        memo.length <= textMaxLength &&
        address.length <= addressMaxLength;
  }

  StopDraft copyWith({
    String? name,
    StopKind? kind,
    int? day,
    LocalTime? Function()? plannedTime,
    String? description,
    String? memo,
    String? address,
    LatLng? Function()? relocatedTo,
    int? Function()? slotOrder,
    PreparedPhoto? Function()? newPhoto,
    bool? removePhoto,
  }) => StopDraft(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    day: day ?? this.day,
    plannedTime: plannedTime == null ? this.plannedTime : plannedTime(),
    description: description ?? this.description,
    memo: memo ?? this.memo,
    address: address ?? this.address,
    relocatedTo: relocatedTo == null ? this.relocatedTo : relocatedTo(),
    slotOrder: slotOrder == null ? this.slotOrder : slotOrder(),
    newPhoto: newPhoto == null ? this.newPhoto : newPhoto(),
    removePhoto: removePhoto ?? this.removePhoto,
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
    latitude: (relocatedTo ?? position).latitude,
    longitude: (relocatedTo ?? position).longitude,
    name: name.trim(),
    kind: kind,
    day: day,
    order: order,
    plannedTime: plannedTime,
    description: description.trim(),
    memo: memo.trim(),
    address: address.trim(),
  );

  /// [stop]에 고친 값을 넣는다. 일차는 바꾸지 않는다(옮기기는 저장소의 `moveStop`이다).
  Stop applyTo(Stop stop) => stop.copyWith(
    latitude: relocatedTo?.latitude,
    longitude: relocatedTo?.longitude,
    name: name.trim(),
    kind: kind,
    plannedTime: () => plannedTime,
    description: description.trim(),
    memo: memo.trim(),
    address: address.trim(),
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
      other.address == address &&
      other.relocatedTo == relocatedTo &&
      other.slotOrder == slotOrder &&
      // 같은 사진을 다시 골라도 새로 줄인 것이라 다른 값으로 본다.
      identical(other.newPhoto, newPhoto) &&
      other.removePhoto == removePhoto;

  @override
  int get hashCode => Object.hash(
    name,
    kind,
    day,
    plannedTime,
    description,
    memo,
    address,
    relocatedTo,
    slotOrder,
    newPhoto,
    removePhoto,
  );
}

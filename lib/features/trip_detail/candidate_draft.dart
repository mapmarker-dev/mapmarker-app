import 'package:flutter/foundation.dart';

import '../../core/map/geo.dart';
import '../../data/models/candidate.dart';
import '../../data/models/stop.dart';
import 'stop_draft.dart';

/// 후보 입력 화면에서 고치는 값. 저장과 고치기가 함께 쓴다. 좌표는 고치지 않는다.
/// 일차·예정 시각은 없다.
@immutable
class CandidateDraft {
  const CandidateDraft({
    this.name = '',
    this.kind = StopKind.other,
    this.description = '',
    this.memo = '',
    this.address = '',
    this.relocatedTo,
  });

  factory CandidateDraft.of(Candidate candidate) => CandidateDraft(
    name: candidate.name,
    kind: candidate.kind,
    description: candidate.description,
    memo: candidate.memo,
    address: candidate.address,
  );

  final String name;
  final StopKind kind;
  final String description;
  final String memo;

  /// 주소. 비어 있어도 된다. 좌표와 따로 고친다.
  final String address;

  /// [주소로 위치 다시 찾기]로 고른 새 좌표. 저장하면 후보가 여기로 옮겨진다. null이면 그대로다.
  final LatLng? relocatedTo;

  /// 저장할 수 있는지. 상한은 장소와 같다(동선에 넣으면 장소가 된다).
  bool get isValid {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= StopDraft.nameMaxLength &&
        description.length <= StopDraft.textMaxLength &&
        memo.length <= StopDraft.textMaxLength &&
        address.length <= StopDraft.addressMaxLength;
  }

  CandidateDraft copyWith({
    String? name,
    StopKind? kind,
    String? description,
    String? memo,
    String? address,
    LatLng? Function()? relocatedTo,
  }) => CandidateDraft(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    memo: memo ?? this.memo,
    address: address ?? this.address,
    relocatedTo: relocatedTo == null ? this.relocatedTo : relocatedTo(),
  );

  Candidate toNewCandidate({
    required String id,
    required String tripId,
    required LatLng position,
  }) => Candidate(
    id: id,
    tripId: tripId,
    latitude: (relocatedTo ?? position).latitude,
    longitude: (relocatedTo ?? position).longitude,
    name: name.trim(),
    kind: kind,
    description: description.trim(),
    memo: memo.trim(),
    address: address.trim(),
  );

  /// [candidate]에 고친 값을 넣는다.
  Candidate applyTo(Candidate candidate) => candidate.copyWith(
    latitude: relocatedTo?.latitude,
    longitude: relocatedTo?.longitude,
    name: name.trim(),
    kind: kind,
    description: description.trim(),
    memo: memo.trim(),
    address: address.trim(),
  );

  @override
  bool operator ==(Object other) =>
      other is CandidateDraft &&
      other.name == name &&
      other.kind == kind &&
      other.description == description &&
      other.memo == memo &&
      other.address == address &&
      other.relocatedTo == relocatedTo;

  @override
  int get hashCode =>
      Object.hash(name, kind, description, memo, address, relocatedTo);
}

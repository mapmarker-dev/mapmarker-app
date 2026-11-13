import 'package:flutter/foundation.dart';

import '../../core/map/geo.dart';
import '../../data/models/candidate.dart';
import '../../data/models/stop.dart';
import 'stop_draft.dart';

/// 후보 입력 화면에서 고치는 값. 저장과 고치기가 함께 쓴다. 좌표는 고치지 않는다.
/// 일차·넣을 자리·예정 시각은 없다(동선에 넣을 때 장소 입력 화면에서 정한다).
@immutable
class CandidateDraft {
  const CandidateDraft({
    this.name = '',
    this.kind = StopKind.other,
    this.description = '',
    this.memo = '',
  });

  factory CandidateDraft.of(Candidate candidate) => CandidateDraft(
    name: candidate.name,
    kind: candidate.kind,
    description: candidate.description,
    memo: candidate.memo,
  );

  final String name;
  final StopKind kind;
  final String description;
  final String memo;

  /// 저장할 수 있는지. 상한은 장소와 같다(동선에 넣으면 장소가 된다).
  bool get isValid {
    final trimmed = name.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= StopDraft.nameMaxLength &&
        description.length <= StopDraft.textMaxLength &&
        memo.length <= StopDraft.textMaxLength;
  }

  CandidateDraft copyWith({
    String? name,
    StopKind? kind,
    String? description,
    String? memo,
  }) => CandidateDraft(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    memo: memo ?? this.memo,
  );

  Candidate toNewCandidate({
    required String id,
    required String tripId,
    required LatLng position,
  }) => Candidate(
    id: id,
    tripId: tripId,
    latitude: position.latitude,
    longitude: position.longitude,
    name: name.trim(),
    kind: kind,
    description: description.trim(),
    memo: memo.trim(),
  );

  /// [candidate]에 고친 값을 넣는다.
  Candidate applyTo(Candidate candidate) => candidate.copyWith(
    name: name.trim(),
    kind: kind,
    description: description.trim(),
    memo: memo.trim(),
  );

  @override
  bool operator ==(Object other) =>
      other is CandidateDraft &&
      other.name == name &&
      other.kind == kind &&
      other.description == description &&
      other.memo == memo;

  @override
  int get hashCode => Object.hash(name, kind, description, memo);
}

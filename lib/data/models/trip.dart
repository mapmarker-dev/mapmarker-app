import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import 'map_provider_type.dart';

/// 여행 상태. 기간으로 자동 판단하고, 사용자가 직접 바꿀 수 있다.
enum TripPhase {
  before('여행 전'),
  during('여행 중'),
  after('여행 후');

  const TripPhase(this.label);

  final String label;
}

enum Season {
  spring('봄'),
  summer('여름'),
  autumn('가을'),
  winter('겨울');

  const Season(this.label);

  final String label;

  /// 기상청 구분: 3–5월 봄, 6–8월 여름, 9–11월 가을, 12–2월 겨울.
  static Season ofMonth(int month) => switch (month) {
    3 || 4 || 5 => spring,
    6 || 7 || 8 => summer,
    9 || 10 || 11 => autumn,
    12 || 1 || 2 => winter,
    _ => throw ArgumentError.value(month, 'month'),
  };
}

/// 여행을 만든 방법.
enum TripOrigin { manual, ai, copy }

/// 일정 표기. 0박은 "당일치기", n박은 "n박 n+1일".
String formatNights(int nights) =>
    nights == 0 ? '당일치기' : '$nights박 ${nights + 1}일';

/// 기본 제목: "{지역} {일정} {계절} 여행". 예: "부산 2박 3일 봄 여행", "경주 당일치기 가을 여행".
///
/// 여행을 만드는 중이라 지역이나 계절이 비어 있으면 그 부분을 빼고 만든다.
String defaultTripTitle({
  required String region,
  required int nights,
  Season? season,
}) => [
  region.trim(),
  formatNights(nights),
  if (season != null) season.label,
  '여행',
].where((part) => part.isNotEmpty).join(' ');

/// 여행 기간. 시작일과 종료일 모두 여행에 들어간다.
@immutable
class TripDates {
  TripDates(this.start, this.end)
    : assert(!end.isBefore(start), '종료일이 시작일보다 앞입니다');

  final LocalDate start;
  final LocalDate end;

  /// 몇 박인지. 당일치기는 0이다.
  int get nights => start.daysUntil(end);

  /// 시작일이 속한 계절.
  Season get season => Season.ofMonth(start.month);

  /// [day]일차의 날짜. 1일차가 시작일이다.
  LocalDate dateOfDay(int day) => start.addDays(day - 1);

  /// [today] 기준 상태. 시작일 전이면 전, 시작일부터 종료일까지 중, 그 뒤는 후다.
  TripPhase phaseOn(LocalDate today) {
    if (today.isBefore(start)) return TripPhase.before;
    if (today.isAfter(end)) return TripPhase.after;
    return TripPhase.during;
  }

  /// 예: `2026.10.14 – 10.17`, `2026.12.30 – 2027.01.02`. 당일치기는 `2026.10.14`.
  String get label {
    final from =
        '${start.year}.${_twoDigits(start.month)}.${_twoDigits(start.day)}';
    if (start == end) return from;
    final to = '${_twoDigits(end.month)}.${_twoDigits(end.day)}';
    return end.year == start.year ? '$from – $to' : '$from – ${end.year}.$to';
  }

  @override
  bool operator ==(Object other) =>
      other is TripDates && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TripDates($start, $end)';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// 여행. 장소·구간·사진(`Stop`·`Segment`·`Photo`)은 여행 ID로 이 여행을 가리킨다.
@immutable
class Trip {
  Trip({
    required this.id,
    required this.title,
    required this.region,
    required this.nights,
    required this.season,
    this.dates,
    this.phaseOverride,
    this.mapProvider,
    this.origin = TripOrigin.manual,
    this.copiedFromTripId,
    this.shareId,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(dates == null || dates.nights == nights, '일정은 기간과 같아야 합니다');

  /// 앱에서 만든 UUID v7 (`newId`).
  final String id;

  final String title;

  /// 예: "부산".
  final String region;

  /// 일정. 몇 박인지이고 당일치기는 0이다. 기간이 있으면 기간에서 계산한 값이다.
  final int nights;

  /// 기간이 있으면 시작일의 계절이 기본값이다.
  final Season season;

  /// 없으면 날짜 미정이다.
  final TripDates? dates;

  /// 사용자가 직접 바꾼 상태. 없으면 기간으로 자동 판단한다.
  ///
  /// 자동 상태는 날이 바뀌면 달라지므로 저장하지 않는다.
  final TripPhase? phaseOverride;

  /// 사용자가 직접 고른 지도. 없으면 장소 위치로 자동 선택한다 (2단계).
  final MapProviderType? mapProvider;

  final TripOrigin origin;

  /// [origin]이 복사일 때 원본 여행.
  final String? copiedFromTripId;

  /// 공유 링크 ID. 서버가 만들고, 공유를 끄면 비운다 (3단계).
  final String? shareId;

  /// 저장소가 정한다 (UTC).
  final DateTime createdAt;
  final DateTime updatedAt;

  String get defaultTitle =>
      defaultTripTitle(region: region, nights: nights, season: season);

  /// 직접 바꾼 상태를 빼고 기간으로만 판단한 상태. 기간이 없으면 "전"이다.
  TripPhase autoPhaseOn(LocalDate today) =>
      dates?.phaseOn(today) ?? TripPhase.before;

  TripPhase phaseOn(LocalDate today) => phaseOverride ?? autoPhaseOn(today);

  /// [phaseOverride]는 함수로 받는다. `() => null`을 넘기면 자동으로 되돌린다.
  Trip copyWith({
    String? title,
    ValueGetter<TripPhase?>? phaseOverride,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Trip(
    id: id,
    title: title ?? this.title,
    region: region,
    nights: nights,
    season: season,
    dates: dates,
    phaseOverride: phaseOverride != null ? phaseOverride() : this.phaseOverride,
    mapProvider: mapProvider,
    origin: origin,
    copiedFromTripId: copiedFromTripId,
    shareId: shareId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

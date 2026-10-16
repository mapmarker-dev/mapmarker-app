import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/today.dart';
import '../../data/models/new_id.dart';
import '../../data/models/trip.dart';
import '../../data/trips/trip_repository.dart';

/// 만들고 있는 여행.
@immutable
class TripDraft {
  const TripDraft({
    this.region = '',
    this.dates,
    this.nights = 1,
    this.season,
    this.title = '',
    this.titleEdited = false,
  });

  final String region;

  /// 없으면 날짜 미정이다.
  final TripDates? dates;

  /// 기간이 있으면 기간에서 계산한 값이다.
  final int nights;

  /// 기간이 있으면 시작일의 계절이 자동으로 골라진다. 바꿀 수 있다.
  final Season? season;

  /// 제목 칸에 보이는 글자.
  final String title;

  /// 사용자가 제목을 직접 고쳤는지. 고치기 전에는 제목이 입력을 따라 바뀐다.
  final bool titleEdited;

  String get defaultTitle =>
      defaultTripTitle(region: region, nights: nights, season: season);

  bool get canCreate => region.trim().isNotEmpty && season != null;

  /// [dates]는 함수로 받는다. `() => null`을 넘기면 기간을 지운다.
  TripDraft copyWith({
    String? region,
    ValueGetter<TripDates?>? dates,
    int? nights,
    Season? season,
    String? title,
    bool? titleEdited,
  }) => TripDraft(
    region: region ?? this.region,
    dates: dates != null ? dates() : this.dates,
    nights: nights ?? this.nights,
    season: season ?? this.season,
    title: title ?? this.title,
    titleEdited: titleEdited ?? this.titleEdited,
  );
}

final tripCreateProvider =
    NotifierProvider.autoDispose<TripCreateController, TripDraft>(
      TripCreateController.new,
    );

class TripCreateController extends Notifier<TripDraft> {
  /// 기간 없이 고를 수 있는 가장 긴 일정.
  static const maxNights = 30;

  @override
  TripDraft build() => _followTitle(const TripDraft());

  void setRegion(String region) => _update(state.copyWith(region: region));

  /// 일정과 계절을 기간에 맞춘다.
  void setDates(TripDates dates) => _update(
    state.copyWith(
      dates: () => dates,
      nights: dates.nights,
      season: dates.season,
    ),
  );

  /// 일정과 계절은 그대로 두고, 직접 고칠 수 있게 한다.
  void clearDates() => _update(state.copyWith(dates: () => null));

  /// 기간이 있으면 일정은 기간을 따르므로 바꾸지 않는다.
  void setNights(int nights) {
    if (state.dates != null) return;
    _update(state.copyWith(nights: nights.clamp(0, maxNights)));
  }

  void setSeason(Season season) => _update(state.copyWith(season: season));

  /// 제목을 비우면 다시 입력을 따라 바뀐다.
  void editTitle(String title) => state = state.copyWith(
    title: title,
    titleEdited: title.trim().isNotEmpty,
  );

  /// 여행을 저장하고 돌려준다. 제목이 비어 있으면 기본 제목으로 만든다.
  Future<Trip> create() {
    final draft = state;
    final season = draft.season;
    if (!draft.canCreate || season == null) {
      throw StateError('지역과 계절이 필요합니다');
    }
    final title = draft.title.trim();
    final now = ref.read(clockProvider)().toUtc();
    return ref
        .read(tripRepositoryProvider)
        .createTrip(
          Trip(
            id: newId(),
            title: title.isEmpty ? draft.defaultTitle : title,
            region: draft.region.trim(),
            nights: draft.nights,
            season: season,
            dates: draft.dates,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  void _update(TripDraft draft) => state = _followTitle(draft);

  TripDraft _followTitle(TripDraft draft) =>
      draft.titleEdited ? draft : draft.copyWith(title: draft.defaultTitle);
}

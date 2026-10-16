import '../core/time/local_date.dart';
import '../data/models/new_id.dart';
import '../data/models/trip.dart';
import '../l10n/l10n.dart';

/// 디버그 빌드에서 미리 넣는 여행. [today] 기준으로 전/중/후가 하나씩 보인다.
///
/// 서버가 생기기 전에는 메모리 저장소라서, 실기기로 확인할 때마다 다시 입력하지 않게 한다.
/// 제목은 [l10n]의 기본 제목이다.
List<Trip> sampleTrips({
  required LocalDate today,
  required DateTime now,
  required AppLocalizations l10n,
}) {
  Trip trip(
    String region, {
    required Duration age,
    TripDates? dates,
    int nights = 1,
    Season season = Season.spring,
  }) {
    final tripNights = dates?.nights ?? nights;
    final tripSeason = dates?.season ?? season;
    final at = now.toUtc().subtract(age);
    return Trip(
      id: newId(),
      title: l10n.defaultTripTitle(
        region: region,
        nights: tripNights,
        season: tripSeason,
      ),
      region: region,
      nights: tripNights,
      season: tripSeason,
      dates: dates,
      createdAt: at,
      updatedAt: at,
    );
  }

  return [
    // 중: 어제부터 3박 4일
    trip(
      '제주',
      age: const Duration(hours: 1),
      dates: TripDates(today.addDays(-1), today.addDays(2)),
    ),
    // 전: 날짜 미정. 기간이 없는 여행이 어떻게 보이는지 확인한다.
    trip('강릉', age: const Duration(days: 2), season: Season.winter),
    // 후: 40일 전 2박 3일
    trip(
      '부산',
      age: const Duration(days: 45),
      dates: TripDates(today.addDays(-40), today.addDays(-38)),
    ),
  ];
}

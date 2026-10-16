import '../core/time/local_date.dart';
import '../data/models/new_id.dart';
import '../data/models/stop.dart';
import '../data/models/trip.dart';
import '../l10n/l10n.dart';

/// 샘플 여행과 그 장소. 구간은 저장소가 장소 사이에 잇는다.
typedef SampleTrips = ({List<Trip> trips, List<Stop> stops});

/// 디버그 빌드에서 미리 넣는 여행. [today] 기준으로 전/중/후가 하나씩 보인다.
///
/// 서버가 생기기 전에는 메모리 저장소라서, 실기기로 확인할 때마다 다시 입력하지 않게 한다.
/// 제목은 [l10n]의 기본 제목이다.
/// - 제주: 숙소 연박과 숙소를 옮기는 날, 장소 종류가 모두 들어 있다.
/// - 강릉: 장소가 없는 여행.
/// - 부산: 장소가 없는 일차(2일차).
SampleTrips sampleTrips({
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

  // 중: 어제부터 3박 4일
  final jeju = trip(
    '제주',
    age: const Duration(hours: 1),
    dates: TripDates(today.addDays(-1), today.addDays(2)),
  );
  // 전: 날짜 미정. 기간이 없는 여행이 어떻게 보이는지 확인한다.
  final gangneung = trip(
    '강릉',
    age: const Duration(days: 2),
    season: Season.winter,
  );
  // 후: 40일 전 2박 3일
  final busan = trip(
    '부산',
    age: const Duration(days: 45),
    dates: TripDates(today.addDays(-40), today.addDays(-38)),
  );

  const jejuAirport = _Place('제주국제공항', 33.5070, 126.4929);
  const jejuCityHotel = _Place('제주시 숙소', 33.5170, 126.5210, StopKind.lodging);
  const busanStation = _Place('부산역', 35.1151, 129.0422);

  return (
    trips: [jeju, gangneung, busan],
    stops: [
      ..._stops(jeju, [
        [
          jejuAirport,
          const _Place('용두암', 33.5163, 126.5119, StopKind.tour),
          const _Place('동문재래시장', 33.5122, 126.5274, StopKind.food),
          jejuCityHotel,
        ],
        [
          const _Place('협재해수욕장', 33.3940, 126.2397, StopKind.tour),
          const _Place('오설록 티뮤지엄', 33.3060, 126.2894, StopKind.food),
          jejuCityHotel,
        ],
        [
          const _Place('성산일출봉', 33.4581, 126.9425, StopKind.tour),
          const _Place('섭지코지', 33.4240, 126.9308, StopKind.tour),
          const _Place('매일올레시장', 33.2497, 126.5636, StopKind.food),
          const _Place('서귀포 숙소', 33.2440, 126.5650, StopKind.lodging),
        ],
        [const _Place('천지연폭포', 33.2470, 126.5545, StopKind.tour), jejuAirport],
      ]),
      ..._stops(busan, [
        [
          busanStation,
          const _Place('감천문화마을', 35.0975, 129.0106, StopKind.tour),
          const _Place('자갈치시장', 35.0966, 129.0306, StopKind.food),
          const _Place('해운대 숙소', 35.1610, 129.1630, StopKind.lodging),
        ],
        [],
        [
          const _Place('해운대해수욕장', 35.1587, 129.1604, StopKind.tour),
          const _Place('광안리해수욕장', 35.1532, 129.1186, StopKind.tour),
          busanStation,
        ],
      ]),
    ],
  );
}

class _Place {
  const _Place(
    this.name,
    this.latitude,
    this.longitude, [
    this.kind = StopKind.other,
  ]);

  final String name;
  final double latitude;
  final double longitude;
  final StopKind kind;
}

/// [days]의 n번째 목록이 n+1일차 장소다.
List<Stop> _stops(Trip trip, List<List<_Place>> days) => [
  for (final (index, places) in days.indexed)
    for (final (order, place) in places.indexed)
      Stop(
        id: newId(),
        tripId: trip.id,
        latitude: place.latitude,
        longitude: place.longitude,
        name: place.name,
        kind: place.kind,
        day: index + 1,
        order: order,
      ),
];

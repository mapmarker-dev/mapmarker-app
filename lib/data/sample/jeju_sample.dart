import '../../core/time/local_time.dart';
import '../../l10n/l10n.dart';
import '../models/candidate.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';
import '../trips/route_links.dart';

/// 샘플 여행의 ID. 서버 여행 ID(UUID)와 겹치지 않는다.
const sampleTripId = 'sample-jeju';

/// 샘플 여행인지. 샘플은 보기만 된다.
bool isSampleTrip(String tripId) => tripId == sampleTripId;

/// 샘플 여행과 그 동선.
typedef SampleTrip = ({Trip trip, TripRoute route});

/// 처음 쓰는 사람을 위한 길잡이: 제주 3박 4일 가을 여행. 서버에 넣지 않고 앱에 담아 둔다(OVERVIEW).
///
/// 날짜는 미정이다. 언제 봐도 "여행 전"으로 어색하지 않다.
/// 앱이 하는 일이 한눈에 보이게 숙소 연박과 숙소를 옮기는 날, 장소 종류, 예정 시각·설명·메모,
/// 이동 수단의 선 모양 3갈래(실선·점선·파선)와 갈아타기, 미정 구간, 곡선, 후보 장소를 모두 넣었다.
SampleTrip jejuSample(AppLocalizations l10n) {
  const nights = 3;
  const season = Season.autumn;
  final region = l10n.sampleJejuRegion;
  // 목록에서는 맨 뒤에 놓으니 시각은 쓰지 않는다.
  final at = DateTime.utc(2026);
  final trip = Trip(
    id: sampleTripId,
    title: l10n.defaultTripTitle(
      region: region,
      nights: nights,
      season: season,
    ),
    region: region,
    nights: nights,
    season: season,
    createdAt: at,
    updatedAt: at,
  );

  final airport = _Place(l10n.sampleJejuAirport, 33.5070, 126.4929);
  final cityHotel = _Place(
    l10n.sampleJejuCityHotel,
    33.5170,
    126.5210,
    kind: StopKind.lodging,
  );
  final days = [
    [
      airport.copyWith(plannedTime: const LocalTime(10, 0)),
      _Place(
        l10n.sampleJejuYongduam,
        33.5163,
        126.5119,
        kind: StopKind.tour,
        description: l10n.sampleJejuYongduamDescription,
      ),
      _Place(
        l10n.sampleJejuDongmun,
        33.5122,
        126.5274,
        kind: StopKind.food,
        memo: l10n.sampleJejuDongmunMemo,
      ),
      cityHotel,
    ],
    [
      _Place(
        l10n.sampleJejuHyeopjae,
        33.3940,
        126.2397,
        kind: StopKind.tour,
        description: l10n.sampleJejuHyeopjaeDescription,
      ),
      _Place(l10n.sampleJejuOsulloc, 33.3060, 126.2894, kind: StopKind.food),
      cityHotel,
    ],
    [
      _Place(
        l10n.sampleJejuSeongsan,
        33.4581,
        126.9425,
        kind: StopKind.tour,
        description: l10n.sampleJejuSeongsanDescription,
        plannedTime: const LocalTime(6, 30),
      ),
      _Place(l10n.sampleJejuUdo, 33.5006, 126.9530, kind: StopKind.tour),
      _Place(l10n.sampleJejuOlleMarket, 33.2497, 126.5636, kind: StopKind.food),
      _Place(
        l10n.sampleJejuSeogwipoHotel,
        33.2440,
        126.5650,
        kind: StopKind.lodging,
      ),
    ],
    [
      _Place(
        l10n.sampleJejuCheonjiyeon,
        33.2470,
        126.5545,
        kind: StopKind.tour,
      ),
      airport,
    ],
  ];
  var stopCount = 0;
  final stops = [
    for (final (index, places) in days.indexed)
      for (final (order, place) in places.indexed)
        place.toStop(
          id: '$sampleTripId-stop-${++stopCount}',
          day: index + 1,
          order: order,
        ),
  ];
  var segmentCount = 0;
  final linked = linkStops(
    tripId: sampleTripId,
    stops: stops,
    existing: const [],
    createId: () => '$sampleTripId-segment-${++segmentCount}',
  );

  // 이웃한 두 장소의 이름으로 이동 수단과 곡률을 넣는다. 오설록 → 제주시 숙소는 미정으로 둔다.
  final legs = <(String, String), List<TransportLeg>>{
    (airport.name, l10n.sampleJejuYongduam): const [
      TransportLeg(TransportMode.car, duration: Duration(minutes: 15)),
    ],
    (l10n.sampleJejuYongduam, l10n.sampleJejuDongmun): const [
      TransportLeg(
        TransportMode.bus,
        stopCount: 4,
        duration: Duration(minutes: 15),
      ),
      TransportLeg(TransportMode.walk, duration: Duration(minutes: 5)),
    ],
    (l10n.sampleJejuDongmun, cityHotel.name): const [
      TransportLeg(TransportMode.walk, duration: Duration(minutes: 10)),
    ],
    (cityHotel.name, l10n.sampleJejuHyeopjae): const [
      TransportLeg(TransportMode.car, duration: Duration(minutes: 50)),
    ],
    (l10n.sampleJejuHyeopjae, l10n.sampleJejuOsulloc): const [
      TransportLeg(
        TransportMode.bus,
        stopCount: 2,
        duration: Duration(minutes: 20),
      ),
    ],
    (cityHotel.name, l10n.sampleJejuSeongsan): const [
      TransportLeg(
        TransportMode.car,
        duration: Duration(hours: 1, minutes: 10),
      ),
    ],
    (l10n.sampleJejuSeongsan, l10n.sampleJejuUdo): const [
      TransportLeg(TransportMode.walk, duration: Duration(minutes: 15)),
      TransportLeg(TransportMode.ferry, duration: Duration(minutes: 15)),
    ],
    (l10n.sampleJejuUdo, l10n.sampleJejuOlleMarket): const [
      TransportLeg(TransportMode.ferry, duration: Duration(minutes: 15)),
      TransportLeg(
        TransportMode.bus,
        stopCount: 12,
        duration: Duration(hours: 1, minutes: 20),
      ),
    ],
    (l10n.sampleJejuOlleMarket, l10n.sampleJejuSeogwipoHotel): const [
      TransportLeg(TransportMode.walk, duration: Duration(minutes: 5)),
    ],
    (l10n.sampleJejuCheonjiyeon, airport.name): const [
      TransportLeg(TransportMode.car, duration: Duration(hours: 1)),
    ],
  };
  // 미정 구간도 하나 휘어서 실선 곡선이 보인다.
  final curves = <(String, String), double>{
    (cityHotel.name, l10n.sampleJejuHyeopjae): 0.25,
    (l10n.sampleJejuOsulloc, cityHotel.name): -0.2,
    (l10n.sampleJejuSeongsan, l10n.sampleJejuUdo): -0.4,
  };
  final names = {for (final stop in stops) stop.id: stop.name};
  final segments = [
    for (final segment in linked)
      if ((names[segment.fromStopId]!, names[segment.toStopId]!)
          case final pair)
        segment.copyWith(
          legs: legs[pair] ?? const [],
          curvature: curves[pair] ?? 0,
        ),
  ];
  // 갈지 말지 정하지 않은 곳. "후보" 보기와 지도의 후보 점이 어떻게 보이는지 알 수 있게 넣었다.
  final candidatePlaces = [
    _Place(
      l10n.sampleJejuBijarim,
      33.4907,
      126.8094,
      kind: StopKind.tour,
      description: l10n.sampleJejuBijarimDescription,
    ),
    _Place(
      l10n.sampleJejuAewol,
      33.4627,
      126.3106,
      kind: StopKind.food,
      memo: l10n.sampleJejuAewolMemo,
    ),
    _Place(
      l10n.sampleJejuYeongsil,
      33.3476,
      126.4963,
      kind: StopKind.tour,
      description: l10n.sampleJejuYeongsilDescription,
    ),
  ];
  final candidates = [
    for (final (index, place) in candidatePlaces.indexed)
      place.toCandidate(id: '$sampleTripId-candidate-${index + 1}'),
  ];
  return (
    trip: trip,
    route: TripRoute(stops: stops, segments: segments, candidates: candidates),
  );
}

class _Place {
  const _Place(
    this.name,
    this.latitude,
    this.longitude, {
    this.kind = StopKind.other,
    this.description = '',
    this.memo = '',
    this.plannedTime,
  });

  final String name;
  final double latitude;
  final double longitude;
  final StopKind kind;
  final String description;
  final String memo;
  final LocalTime? plannedTime;

  _Place copyWith({LocalTime? plannedTime}) => _Place(
    name,
    latitude,
    longitude,
    kind: kind,
    description: description,
    memo: memo,
    plannedTime: plannedTime ?? this.plannedTime,
  );

  Stop toStop({required String id, required int day, required int order}) =>
      Stop(
        id: id,
        tripId: sampleTripId,
        latitude: latitude,
        longitude: longitude,
        name: name,
        kind: kind,
        description: description,
        memo: memo,
        plannedTime: plannedTime,
        day: day,
        order: order,
      );

  Candidate toCandidate({required String id}) => Candidate(
    id: id,
    tripId: sampleTripId,
    latitude: latitude,
    longitude: longitude,
    name: name,
    kind: kind,
    description: description,
    memo: memo,
  );
}

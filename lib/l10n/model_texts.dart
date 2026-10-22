import '../data/models/segment.dart';
import '../data/models/stop.dart';
import '../data/models/trip.dart';
import '../data/models/trip_route.dart';
import 'generated/app_localizations.dart';

/// 모델을 화면 글자로 바꾼다. 모델(`data/`)에는 글자를 두지 않는다.
extension ModelTexts on AppLocalizations {
  String tripPhaseName(TripPhase phase) => switch (phase) {
    TripPhase.before => phaseBefore,
    TripPhase.during => phaseDuring,
    TripPhase.after => phaseAfter,
  };

  String seasonName(Season season) => switch (season) {
    Season.spring => seasonSpring,
    Season.summer => seasonSummer,
    Season.autumn => seasonAutumn,
    Season.winter => seasonWinter,
  };

  /// 일정. 예: "당일치기", "2박 3일".
  String nightsText(int nights) => tripLength(nights, nights + 1);

  /// 기본 제목. 예: "부산 2박 3일 봄 여행", "경주 당일치기 가을 여행".
  ///
  /// 여행을 만드는 중에는 지역이 비어 있거나 계절이 없을 수 있다.
  /// 계절이 없으면 계절 없는 문장을 쓰고, 비어 있는 지역 자리에 남는 공백은 지운다.
  String defaultTripTitle({
    required String region,
    required int nights,
    Season? season,
  }) {
    final length = nightsText(nights);
    final title = season == null
        ? tripTitleWithoutSeason(region.trim(), length)
        : tripTitle(region.trim(), length, seasonName(season));
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String defaultTitleOf(Trip trip) => defaultTripTitle(
    region: trip.region,
    nights: trip.nights,
    season: trip.season,
  );

  /// 예: "2026.10.14 – 10.17", "2026.12.30 – 2027.01.02". 당일치기는 "2026.10.14".
  String tripDatesText(TripDates dates) {
    final start = dates.start.toDateTime();
    final end = dates.end.toDateTime();
    if (dates.start == dates.end) return tripDatesOneDay(start);
    return dates.start.year == dates.end.year
        ? tripDatesSameYear(start, end)
        : tripDatesAcrossYears(start, end);
  }

  /// 여행 목록의 기간과 일정. 예: "2026.10.14 – 10.17 · 3박 4일", "날짜 미정 · 1박 2일".
  String tripSummaryOf(Trip trip) {
    final dates = trip.dates;
    return tripSummary(
      dates == null ? tripDatesUndecided : tripDatesText(dates),
      nightsText(trip.nights),
    );
  }

  String stopKindName(StopKind kind) => switch (kind) {
    StopKind.lodging => stopKindLodging,
    StopKind.food => stopKindFood,
    StopKind.tour => stopKindTour,
    StopKind.other => stopKindOther,
  };

  String transportModeName(TransportMode mode) => switch (mode) {
    TransportMode.walk => transportWalk,
    TransportMode.subway => transportSubway,
    TransportMode.bus => transportBus,
    TransportMode.train => transportTrain,
    TransportMode.car => transportCar,
    TransportMode.flight => transportFlight,
    TransportMode.ferry => transportFerry,
  };

  /// 예: "지하철 4정류장", "도보 20분", "비행기 3시간 20분".
  String transportLegText(TransportLeg leg) => [
    transportModeName(leg.mode),
    if (leg.stopCount case final count?) transportStops(count),
    if (leg.duration case final duration?) durationText(duration),
  ].join(' ');

  /// 구간의 이동 수단. 갈아타면 +로 잇는다. 예: "지하철 2정류장 + 도보".
  /// 이동 수단을 정하지 않았으면 빈 글자다.
  String transportText(Segment segment) =>
      segment.legs.map(transportLegText).join(transportLegSeparator);

  /// 구간이 어느 일차의 어느 장소 사이인지. 이동 수단이 사라진다고 물을 때 보여 준다.
  /// 예: "2일차 용두암 → 동문시장".
  /// 
  /// 숙소가 아닌 장소에서 다음 날로 넘어가는 구간은 밤 이동인지 아침 이동인지 몰라서 양쪽에 일차를 붙인다: "1일차 제주국제공항 → 2일차 용두암".
  ///
  /// 양 끝 장소가 [route]에 없으면 null이다.
  String? segmentRouteText(TripRoute route, Segment segment) {
    final from = route.stopById(segment.fromStopId);
    final to = route.stopById(segment.toStopId);
    if (from == null || to == null) return null;
    return from.day == to.day || from.isLodging
        ? droppedTransportRoute(to.day, from.name, to.name)
        : droppedTransportRouteAcrossDays(from.day, from.name, to.day, to.name);
  }

  /// 갈아타는 토막 사이. 일차 동선 목록이 토막마다 아이콘을 붙일 때도 쓴다.
  String get transportLegSeparator => ' + ';

  /// 예: "20분", "2시간", "3시간 20분".
  String durationText(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours == 0) return durationMinutes(minutes);
    if (minutes == 0) return durationHours(hours);
    return durationHoursMinutes(hours, minutes);
  }
}

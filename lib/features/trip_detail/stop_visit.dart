import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../core/time/zoned_time.dart';
import '../../data/models/stop.dart';
import '../../data/models/trip.dart';

/// 방문 완료와 취소 규칙. 화면 밖에서 시험할 수 있게 따로 둔다.
///
/// 방문 시각은 순간(UTC)으로 저장하고 장소의 시간대([Stop.timeZone])로 보여 준다.

/// [방문 완료]와 [방문 취소]를 보여 줄지. 여행 중과 여행 후에만 보인다(여행 전에는 다녀올 곳이 없다).
/// 방문한 표시와 장소 편집의 방문 시각 칸은 이와 상관없이 보인다.
bool showsVisitButtons(Trip trip, LocalDate today) =>
    trip.phaseOn(today) != TripPhase.before;

/// 예정 시각이 없는 장소를 지난 날짜로 기록할 때의 시각.
const visitFallbackTime = LocalTime(12, 0);

/// [방문 완료]를 눌렀을 때 기록할 시각.
///
/// 누른 순간이 기본이다. 다만 장소의 일차 날짜(여행 기간이 있을 때)가 장소 현지의 오늘보다 앞이면
/// 그날의 예정 시각(없으면 낮 12시)으로 넣는다. 여행이 끝난 뒤나 다음 날 체크해도 오늘 날짜로 남지 않게 한다.
/// 날짜와 시각은 장소 편집에서 고친다.
DateTime defaultVisitTime(Trip trip, Stop stop, DateTime now) {
  final dayDate = trip.dates?.dateOfDay(stop.day);
  final today = zonedParts(now, stop.timeZone).date;
  if (dayDate == null || !dayDate.isBefore(today)) return now.toUtc();
  return zonedInstant(
    dayDate,
    stop.plannedTime ?? visitFallbackTime,
    stop.timeZone,
  );
}

/// 방문 날짜로 고를 수 있는 범위. 미래는 고를 수 없다.
///
/// 기간이 있는 여행은 기간 안에서 오늘까지, 기간이 없으면 지난 1년이다.
/// 기간이 오늘보다 뒤로 옮겨졌으면(이미 방문을 기록한 뒤) 시작일 하루만 고른다.
({LocalDate first, LocalDate last}) visitDateRange(Trip trip, LocalDate today) {
  final dates = trip.dates;
  if (dates == null) return (first: today.addDays(-365), last: today);
  final last = dates.end.isBefore(today) ? dates.end : today;
  return (
    first: dates.start,
    last: last.isBefore(dates.start) ? dates.start : last,
  );
}

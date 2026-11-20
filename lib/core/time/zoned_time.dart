import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'local_date.dart';
import 'local_time.dart';

/// 순간(UTC)과 장소의 현지 날짜·시각을 오간다. 장소의 시간대는 IANA 이름이다(예: `Asia/Seoul`).
///
/// 방문 시각은 순간으로 저장하고 화면에는 장소의 현지 시각으로 보여 준다. 기기 시간대가 아니라 장소의 것이라
/// 해외 장소를 한국에서 보거나 고쳐도 현지 시각 그대로다(OVERVIEW "데이터와 시간").
/// 시간대 자료는 처음 쓸 때 한 번 읽는다. 모르는 이름이면 기기 시간대로 읽는다.

bool _loaded = false;

tz.Location? _locationOf(String timeZone) {
  if (!_loaded) {
    tz_data.initializeTimeZones();
    _loaded = true;
  }
  try {
    return tz.getLocation(timeZone);
  } on tz.LocationNotFoundException {
    return null;
  }
}

/// [instant]의 [timeZone] 현지 날짜와 시:분.
({LocalDate date, LocalTime time}) zonedParts(
  DateTime instant,
  String timeZone,
) {
  final location = _locationOf(timeZone);
  final DateTime local = location == null
      ? instant.toLocal()
      : tz.TZDateTime.from(instant, location);
  return (
    date: LocalDate(local.year, local.month, local.day),
    time: LocalTime(local.hour, local.minute),
  );
}

/// [timeZone]의 현지 [date] [time]이 가리키는 순간(UTC).
/// 서머타임으로 없는 시각이면 timezone 패키지가 정한 가까운 순간이다.
DateTime zonedInstant(LocalDate date, LocalTime time, String timeZone) {
  final location = _locationOf(timeZone);
  if (location == null) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();
  }
  return tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).toUtc();
}

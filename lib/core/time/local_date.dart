import 'package:flutter/foundation.dart';

/// 시간대 없는 날짜(연·월·일).

@immutable
class LocalDate implements Comparable<LocalDate> {
  /// 범위를 넘는 값은 달력에 맞게 넘긴다. 예: `LocalDate(2026, 1, 32)`는 2월 1일이다.
  factory LocalDate(int year, int month, int day) {
    final utc = DateTime.utc(year, month, day);
    return LocalDate._(utc.year, utc.month, utc.day);
  }

  /// [dateTime]의 연·월·일만 쓴다. 시간대는 바꾸지 않는다.
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  const LocalDate._(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  /// 날짜 계산용. UTC에는 서머타임이 없어서 하루가 항상 24시간이다.
  DateTime get _utc => DateTime.utc(year, month, day);

  /// 기기 시간대의 그날 0시. 날짜 선택기나 날짜 표기에 넘길 때 쓴다.
  DateTime toDateTime() => DateTime(year, month, day);

  LocalDate addDays(int days) => LocalDate(year, month, day + days);

  /// [other]까지 며칠인지. [other]가 앞이면 음수다.
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `2026-10-15` 형식.
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${_twoDigits(month)}-${_twoDigits(day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

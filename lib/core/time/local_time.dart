import 'package:flutter/foundation.dart';

/// 시간대 없는 시각(시:분). 예정 시각처럼 현지 시각 그대로 보여 줄 값에 쓴다.
@immutable
class LocalTime implements Comparable<LocalTime> {
  const LocalTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  @override
  int compareTo(LocalTime other) =>
      (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) =>
      other is LocalTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  /// `09:30` 형식.
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

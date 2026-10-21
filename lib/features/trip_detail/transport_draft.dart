import 'package:flutter/foundation.dart';

import '../../data/models/segment.dart';

/// 정류장 수를 받는 수단. 기차는 보통 걸리는 시간으로 기억해서 받지 않는다.
bool countsStops(TransportMode mode) =>
    mode == TransportMode.subway || mode == TransportMode.bus;

/// 이동 수단 입력 화면에서 고치는 값. 토막을 갈아타는 차례대로 담는다.
///
/// 칸에 적은 글자를 그대로 들고 있다가 저장할 때 [toLegs]로 바꾼다.
/// 틀린 값도 칸 아래에 알려 주려고 숫자로 미리 바꾸지 않는다.
@immutable
class TransportDraft {
  const TransportDraft([this.legs = const []]);

  factory TransportDraft.of(Segment segment) =>
      TransportDraft([for (final leg in segment.legs) LegDraft.of(leg)]);

  /// 한 구간에 이을 수 있는 토막 수. 예: 도보 + 지하철 + 도보 + 버스 + 도보.
  static const maxLegs = 5;

  /// 비어 있으면 이동 수단 미정이다.
  final List<LegDraft> legs;

  bool get canAddLeg => legs.length < maxLegs;

  bool get isValid => legs.length <= maxLegs && legs.every((l) => l.isValid);

  /// 저장할 토막. [isValid]일 때만 부른다.
  List<TransportLeg> toLegs() => [for (final leg in legs) leg.toLeg()];

  @override
  bool operator ==(Object other) =>
      other is TransportDraft && listEquals(other.legs, legs);

  @override
  int get hashCode => Object.hashAll(legs);
}

/// 토막 하나의 입력 값. 칸은 숫자만 2자리까지 받는다(입력 화면이 막는다).
@immutable
class LegDraft {
  const LegDraft(
    this.mode, {
    this.stops = '',
    this.hours = '',
    this.minutes = '',
  });

  factory LegDraft.of(TransportLeg leg) {
    final duration = leg.duration;
    final hours = duration?.inHours ?? 0;
    final minutes = (duration?.inMinutes ?? 0) % 60;
    return LegDraft(
      leg.mode,
      stops: leg.stopCount?.toString() ?? '',
      hours: hours == 0 ? '' : '$hours',
      minutes: minutes == 0 ? '' : '$minutes',
    );
  }

  static const maxStops = 99;
  static const maxHours = 99;
  static const maxMinutes = 59;

  final TransportMode mode;

  /// 정류장 수 칸. [countsStops]가 아닌 수단이면 칸이 숨고, 저장할 때 버린다.
  /// 수단을 다시 바꾸면 적어 둔 값이 돌아오게 남겨 둔다.
  final String stops;

  /// 걸리는 시간의 시간 칸과 분 칸. 둘 다 비거나 합이 0이면 시간 없음이다.
  final String hours;
  final String minutes;

  /// 정류장 수가 맞는지. 비우면 맞다. 1~[maxStops].
  bool get stopsValid =>
      !countsStops(mode) || stops.isEmpty || _inRange(stops, 1, maxStops);

  /// 시간 칸이 맞는지. 비우면 맞다. 0~[maxHours].
  bool get hoursValid => hours.isEmpty || _inRange(hours, 0, maxHours);

  /// 분 칸이 맞는지. 비우면 맞다. 0~[maxMinutes]. 60분 이상은 시간 칸에 적는다.
  bool get minutesValid => minutes.isEmpty || _inRange(minutes, 0, maxMinutes);

  bool get isValid => stopsValid && hoursValid && minutesValid;

  /// 저장할 토막. [isValid]일 때만 부른다.
  TransportLeg toLeg() {
    final total =
        (int.tryParse(hours) ?? 0) * 60 + (int.tryParse(minutes) ?? 0);
    return TransportLeg(
      mode,
      stopCount: countsStops(mode) ? int.tryParse(stops) : null,
      duration: total == 0 ? null : Duration(minutes: total),
    );
  }

  LegDraft copyWith({
    TransportMode? mode,
    String? stops,
    String? hours,
    String? minutes,
  }) => LegDraft(
    mode ?? this.mode,
    stops: stops ?? this.stops,
    hours: hours ?? this.hours,
    minutes: minutes ?? this.minutes,
  );

  static bool _inRange(String text, int min, int max) {
    final value = int.tryParse(text);
    return value != null && value >= min && value <= max;
  }

  @override
  bool operator ==(Object other) =>
      other is LegDraft &&
      other.mode == mode &&
      other.stops == stops &&
      other.hours == hours &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(mode, stops, hours, minutes);

  @override
  String toString() => 'LegDraft($mode, $stops, $hours, $minutes)';
}

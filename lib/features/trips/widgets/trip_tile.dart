import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../../../data/models/trip.dart';
import '../../../l10n/l10n.dart';
import 'trip_phase_menu.dart';

/// 여행 목록의 한 줄. 제목, 기간과 일정, 상태가 보인다.
class TripTile extends StatelessWidget {
  const TripTile({
    super.key,
    required this.trip,
    required this.today,
    required this.onTap,
    required this.onPhaseChanged,
  });

  final Trip trip;
  final LocalDate today;
  final VoidCallback onTap;

  /// 고른 상태. null이면 자동으로 되돌린다.
  final ValueChanged<TripPhase?> onPhaseChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(trip.title),
      subtitle: Text(context.l10n.tripSummaryOf(trip)),
      trailing: TripPhaseMenu(
        phase: trip.phaseOn(today),
        autoPhase: trip.autoPhaseOn(today),
        isManual: trip.phaseOverride != null,
        onChanged: onPhaseChanged,
      ),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_date.dart';
import '../../../data/models/trip.dart';
import '../../../l10n/l10n.dart';
import 'trip_phase_menu.dart';

/// 여행 목록의 정사각형 카드. 위에 상태, 가운데 제목, 아래에 기간과 일정이 보인다.
class TripCard extends StatelessWidget {
  const TripCard({
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
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final phase = trip.phaseOn(today);
    return Card(
      // 여행 중인 카드는 코랄 테두리로 강조한다.
      shape: phase == TripPhase.during
          ? RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: BorderSide(
                color: context.appColors.cardHighlight,
                width: 2,
              ),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TripPhaseMenu(
                phase: phase,
                autoPhase: trip.autoPhaseOn(today),
                isManual: trip.phaseOverride != null,
                onChanged: onPhaseChanged,
              ),
              const SizedBox(height: AppSpace.sm),
              Expanded(
                child: Text(
                  trip.title,
                  style: textTheme.titleMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                context.l10n.tripSummaryOf(trip),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

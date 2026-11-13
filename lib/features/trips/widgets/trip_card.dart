import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_date.dart';
import '../../../data/models/trip.dart';
import '../../../data/sample/jeju_sample.dart';
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
    required this.onDelete,
  });

  final Trip trip;
  final LocalDate today;
  final VoidCallback onTap;

  /// 고른 상태를 저장한다(null이면 자동으로 되돌린다). 저장될 때까지 상태 칩에 진행 표시가 돈다.
  final Future<void> Function(TripPhase? phase) onPhaseChanged;

  /// ⋮ 메뉴의 "여행 지우기"(샘플은 "샘플 지우기"). 확인은 부른 쪽이 받는다.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final phase = trip.phaseOn(today);
    // 샘플은 보기만 된다. 상태를 고를 수 없고, "샘플" 표시가 붙는다.
    final sample = isSampleTrip(trip.id);
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
              Row(
                children: [
                  // 좁은 카드에서 "여행 중 · 직접" 칩이 ⋮ 버튼과 부딪히면 칩을 줄여 맞춘다.
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TripPhaseMenu(
                              phase: phase,
                              autoPhase: trip.autoPhaseOn(today),
                              isManual: trip.phaseOverride != null,
                              onChanged: sample ? null : onPhaseChanged,
                            ),
                            if (sample) ...[
                              const SizedBox(width: AppSpace.xs),
                              const _SampleBadge(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  _CardMenu(onDelete: onDelete, sample: sample),
                ],
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

/// 카드 오른쪽 위 ⋮ 메뉴. 카드가 작아서 아이콘 버튼을 줄여 상태 칩 줄의 높이를 크게 늘리지 않는다.
class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onDelete, required this.sample});

  final VoidCallback onDelete;
  final bool sample;

  static const _size = 32.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox.square(
      dimension: _size,
      child: PopupMenuButton<VoidCallback>(
        tooltip: l10n.tripMenuTooltip,
        padding: EdgeInsets.zero,
        iconSize: 20,
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: onDelete,
            child: Text(sample ? l10n.deleteSample : l10n.deleteTrip),
          ),
        ],
      ),
    );
  }
}

/// 샘플 여행 카드의 "샘플" 표시. 상태 칩 옆에 테두리만 있는 작은 칩으로 둔다.
class _SampleBadge extends StatelessWidget {
  const _SampleBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Text(
          context.l10n.sampleBadge,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

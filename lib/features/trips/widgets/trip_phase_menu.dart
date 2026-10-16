import 'package:flutter/material.dart';

import '../../../data/models/trip.dart';
import '../../../l10n/l10n.dart';

/// 상태 칩. 누르면 상태를 직접 고르거나 자동으로 되돌리는 메뉴가 열린다.
class TripPhaseMenu extends StatelessWidget {
  const TripPhaseMenu({
    super.key,
    required this.phase,
    required this.autoPhase,
    required this.isManual,
    required this.onChanged,
  });

  /// 지금 보이는 상태.
  final TripPhase phase;

  /// 기간으로만 판단한 상태. "자동으로 되돌리기"에 미리 보여 준다.
  final TripPhase autoPhase;

  /// 사용자가 직접 바꾼 상태인지.
  final bool isManual;

  /// 고른 상태. null이면 자동으로 되돌린다.
  final ValueChanged<TripPhase?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<({TripPhase? phase})>(
      tooltip: l10n.changePhaseTooltip,
      onSelected: (choice) => onChanged(choice.phase),
      itemBuilder: (context) => [
        for (final item in TripPhase.values)
          CheckedPopupMenuItem(
            value: (phase: item),
            checked: item == phase,
            child: Text(l10n.tripPhaseName(item)),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: (phase: null),
          enabled: isManual,
          child: Text(l10n.revertPhaseToAuto(l10n.tripPhaseName(autoPhase))),
        ),
      ],
      child: _PhaseChip(phase: phase, isManual: isManual),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase, required this.isManual});

  final TripPhase phase;
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = l10n.tripPhaseName(phase);
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (phase) {
      TripPhase.before => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      TripPhase.during => (colors.primaryContainer, colors.onPrimaryContainer),
      TripPhase.after => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isManual ? l10n.phaseManual(name) : name,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}

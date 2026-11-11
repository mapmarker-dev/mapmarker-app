import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/trip.dart';
import '../../../l10n/l10n.dart';

/// 상태 칩. 누르면 상태를 직접 고르거나 자동으로 되돌리는 메뉴가 열린다.
///
/// 고르면 저장될 때까지 칩에 진행 표시가 돌고 다시 고를 수 없다. 칩은 저장되면 새 상태로 바뀐다.
class TripPhaseMenu extends StatefulWidget {
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

  /// 고른 상태를 저장한다. null을 고르면 자동으로 되돌린다. 실패 안내는 부른 쪽이 한다.
  /// 이것이 null이면 상태를 고를 수 없다(샘플 여행). 칩만 보인다.
  final Future<void> Function(TripPhase? phase)? onChanged;

  @override
  State<TripPhaseMenu> createState() => _TripPhaseMenuState();
}

class _TripPhaseMenuState extends State<TripPhaseMenu> {
  bool _saving = false;

  Future<void> _change(TripPhase? phase) async {
    setState(() => _saving = true);
    try {
      await widget.onChanged?.call(phase);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phase = widget.phase;
    if (widget.onChanged == null) {
      return _PhaseChip(
        phase: phase,
        isManual: widget.isManual,
        saving: false,
        canChange: false,
      );
    }
    final menu = PopupMenuButton<({TripPhase? phase})>(
      tooltip: l10n.changePhaseTooltip,
      enabled: !_saving,
      onSelected: (choice) => _change(choice.phase),
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
          enabled: widget.isManual,
          child: Text(
            l10n.revertPhaseToAuto(l10n.tripPhaseName(widget.autoPhase)),
          ),
        ),
      ],
      child: _PhaseChip(
        phase: phase,
        isManual: widget.isManual,
        saving: _saving,
        canChange: true,
      ),
    );
    // 잠긴 메뉴는 눌림을 받지 않아서 카드로 넘어가 여행이 열린다. 저장하는 동안은 여기서 삼킨다.
    if (!_saving) return menu;
    return GestureDetector(onTap: () {}, child: menu);
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.phase,
    required this.isManual,
    required this.saving,
    required this.canChange,
  });

  final TripPhase phase;
  final bool isManual;

  /// 고를 수 있는지. 없으면 펼침 화살표가 없다.
  final bool canChange;

  /// 고른 상태를 저장하는 중. 펼침 화살표 자리에 진행 표시가 돈다.
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = l10n.tripPhaseName(phase);
    final appColors = context.appColors;
    final colors = switch (phase) {
      TripPhase.before => appColors.phaseBefore,
      TripPhase.during => appColors.phaseDuring,
      TripPhase.after => appColors.phaseAfter,
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.xs,
          AppSpace.xs,
          AppSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isManual ? l10n.phaseManual(name) : name,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.foreground),
            ),
            if (saving)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                child: SavingIndicator(
                  label: l10n.saving,
                  size: 10,
                  padded: false,
                  color: colors.foreground,
                ),
              )
            else if (canChange)
              Icon(Icons.arrow_drop_down, size: 18, color: colors.foreground),
          ],
        ),
      ),
    );
  }
}

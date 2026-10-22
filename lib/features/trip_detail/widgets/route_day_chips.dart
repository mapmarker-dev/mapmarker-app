import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';

/// 일차 칩 줄: 전체, 1일차, 2일차 …, 숙소 켜기/끄기. 일차가 많으면 가로로 넘긴다.
///
/// 일차 칩의 점은 그 일차의 동선 색이다. 장소가 없는 일차도 칩은 보인다.
class RouteDayChips extends StatelessWidget {
  const RouteDayChips({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.showLodging,
    required this.onDaySelected,
    required this.onShowLodgingChanged,
    this.padding = EdgeInsets.zero,
  });

  /// 여행 일수.
  final int days;

  /// null이면 여행 전체다.
  final int? selectedDay;
  final bool showLodging;
  final ValueChanged<int?> onDaySelected;
  final ValueChanged<bool> onShowLodgingChanged;
  final EdgeInsets padding;

  static const _dot = 12.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appColors = context.appColors;
    // 지도 위에 떠 있어서, 고르지 않은 칩도 바탕을 채운다.
    final background = Theme.of(context).colorScheme.surfaceContainerLowest;

    Widget dayChip(int? day, String label) => ChoiceChip(
      avatar: day == null
          ? null
          : Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: appColors.routeDay(day).background,
                shape: BoxShape.circle,
              ),
            ),
      label: Text(label),
      selected: selectedDay == day,
      showCheckmark: false,
      backgroundColor: background,
      onSelected: (_) => onDaySelected(day),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        spacing: AppSpace.sm,
        children: [
          dayChip(null, l10n.routeAllDays),
          for (var day = 1; day <= days; day++)
            dayChip(day, l10n.routeDay(day)),
          FilterChip(
            label: Text(l10n.routeShowLodging),
            selected: showLodging,
            backgroundColor: background,
            onSelected: onShowLodgingChanged,
          ),
        ],
      ),
    );
  }
}

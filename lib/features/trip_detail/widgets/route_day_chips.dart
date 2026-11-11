import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';

/// 일차 칩 줄: 전체, 1일차, 2일차 …, 후보, 그리고 필터 칩 숙소·후보 보기. 일차가 많으면 가로로 넘긴다.
///
/// 일차 칩의 점은 그 일차의 동선 색이다. 장소가 없는 일차도 칩은 보인다.
/// "후보"는 일차처럼 고르는 보기(후보 목록)이고, "후보 보기"는 다른 보기에도 후보를 보일지 켜고 끄는 필터다.
class RouteDayChips extends StatelessWidget {
  const RouteDayChips({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.candidateView,
    required this.showLodging,
    required this.showCandidates,
    required this.onDaySelected,
    required this.onCandidatesSelected,
    required this.onShowLodgingChanged,
    required this.onShowCandidatesChanged,
    this.padding = EdgeInsets.zero,
  });

  /// 여행 일수.
  final int days;

  /// null이면 여행 전체다([candidateView]가 아닐 때).
  final int? selectedDay;

  /// "후보" 보기를 고르고 있다.
  final bool candidateView;

  final bool showLodging;
  final bool showCandidates;
  final ValueChanged<int?> onDaySelected;
  final VoidCallback onCandidatesSelected;
  final ValueChanged<bool> onShowLodgingChanged;
  final ValueChanged<bool> onShowCandidatesChanged;
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
      selected: !candidateView && selectedDay == day,
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
          ChoiceChip(
            // 후보 마커와 같은 흰 바탕·회색 테두리 점.
            avatar: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: appColors.routeCandidate.background,
                shape: BoxShape.circle,
                border: Border.all(color: appColors.routeCandidateRing),
              ),
            ),
            label: Text(l10n.routeCandidates),
            selected: candidateView,
            showCheckmark: false,
            backgroundColor: background,
            onSelected: (_) => onCandidatesSelected(),
          ),
          FilterChip(
            label: Text(l10n.routeShowLodging),
            selected: showLodging,
            backgroundColor: background,
            onSelected: onShowLodgingChanged,
          ),
          FilterChip(
            label: Text(l10n.routeShowCandidates),
            selected: showCandidates,
            backgroundColor: background,
            onSelected: onShowCandidatesChanged,
          ),
        ],
      ),
    );
  }
}

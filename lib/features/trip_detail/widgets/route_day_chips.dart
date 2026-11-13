import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';

/// 동선 페이지의 칩 두 줄.
///
/// 첫 줄은 하나만 고르는 보기다: 전체, 1일차, 2일차 …, 후보 목록. 일차가 많으면 가로로 넘긴다.
/// 일차 칩의 점은 그 일차의 동선 색이다. 장소가 없는 일차도 칩은 보인다.
///
/// 둘째 줄은 "함께 보기" 뒤에 켜고 끄는 필터 숙소·후보다. 숙소는 지도와 목록에서 숙소를 숨기고,
/// 후보는 전체·일차 보기의 지도에 후보 점을 보인다. 보기와 필터를 한 줄에 두었더니 "후보"(보기)와
/// "후보 보기"(필터)가 헷갈려서 줄을 나눴다.
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

  /// "후보 목록" 보기를 고르고 있다.
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

    final views = SingleChildScrollView(
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
        ],
      ),
    );

    // 필터 칩은 보기 칩보다 작게, 글과 함께 바탕 하나에 묶는다(지도 위에서 글이 묻히지 않게).
    // 지도를 덜 가리려고 누르는 영역도 보이는 크기로 줄인다.
    Widget filter(String label, bool selected, ValueChanged<bool> onChanged) =>
        FilterChip(
          label: Text(label),
          selected: selected,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: background,
          onSelected: onChanged,
        );
    final filters = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpace.xs,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                child: Text(
                  l10n.routeAlsoShow,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              filter(l10n.routeShowLodging, showLodging, onShowLodgingChanged),
              filter(
                l10n.routeShowCandidates,
                showCandidates,
                onShowCandidatesChanged,
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      // 보기 칩의 누르는 영역(48)이 보이는 칩보다 위아래로 커서 줄 사이는 따로 띄우지 않는다.
      children: [
        views,
        Align(alignment: AlignmentDirectional.centerStart, child: filters),
      ],
    );
  }
}

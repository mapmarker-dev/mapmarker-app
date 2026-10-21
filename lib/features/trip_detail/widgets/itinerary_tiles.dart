import 'package:flutter/material.dart';

import '../../../core/map/map_provider.dart';
import '../../../core/map/marker_icon.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/segment.dart';
import '../../../data/models/stop.dart';
import '../../../l10n/l10n.dart';

/// 일차 동선 시트의 장소 줄.
///
/// 이름 쪽을 누르면 펼쳐져서 설명 전체, 메모, 편집·지우기 버튼이 나온다.
/// 아래 칸을 누르면 외부 지도(네이버)에서 장소를 연다. 영업시간, 리뷰는 거기서 본다.
class ItineraryStopTile extends StatelessWidget {
  const ItineraryStopTile({
    super.key,
    required this.stop,
    required this.look,
    required this.expanded,
    required this.highlighted,
    required this.onToggle,
    required this.onOpenMap,
    required this.onEdit,
    this.caption,
    this.onDelete,
    this.reorderHandle,
  });

  final Stop stop;

  /// 지도 마커와 같은 그림.
  final MarkerLook look;

  final bool expanded;

  /// 고른 장소. 지도에서 마커를 누르거나 시트에서 이 줄을 누른 것이다.
  final bool highlighted;

  final VoidCallback onToggle;
  final VoidCallback onOpenMap;
  final VoidCallback onEdit;

  /// 이름 위의 작은 글자. 예: 출발 숙소 표시.
  final String? caption;

  /// null이면 지우기 버튼이 없다(출발 숙소).
  final VoidCallback? onDelete;

  /// 끌어서 순서를 바꾸는 손잡이. null이면 옮길 수 없다.
  final Widget? reorderHandle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final kind = l10n.stopKindName(stop.kind);
    final time = stop.plannedTime;
    final description = stop.description.trim();
    final memo = stop.memo.trim();

    return Material(
      color: highlighted ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: AppRadius.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: AppRadius.md,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkerIcon(look),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (caption case final caption?)
                            Text(caption, style: muted),
                          Text(
                            stop.name,
                            style: textTheme.titleSmall,
                            maxLines: expanded ? null : 1,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                          ),
                          Text(
                            time == null
                                ? kind
                                : l10n.itineraryKindAndTime(
                                    kind,
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatTimeOfDay(
                                      TimeOfDay(
                                        hour: time.hour,
                                        minute: time.minute,
                                      ),
                                    ),
                                  ),
                            style: muted,
                          ),
                          if (description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.xs),
                              child: Text(
                                description,
                                style: textTheme.bodyMedium,
                                maxLines: expanded ? null : 2,
                                overflow: expanded
                                    ? null
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                          if (expanded && memo.isNotEmpty) ...[
                            const SizedBox(height: AppSpace.sm),
                            Text(l10n.itineraryMemo, style: muted),
                            Text(memo, style: textTheme.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                    ?reorderHandle,
                  ],
                ),
              ),
            ),
            Padding(
              // 글자 줄과 첫 글자를 맞춘다. 링크 자체의 안쪽 여백만큼 덜 들인다.
              padding: EdgeInsets.only(
                left: AppSpace.sm + _iconWidth + AppSpace.md - AppSpace.xs,
                right: AppSpace.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _OpenMapLink(onTap: onOpenMap),
              ),
            ),
            if (expanded)
              Padding(
                padding: EdgeInsets.only(left: AppSpace.sm + _iconWidth),
                child: Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.editStop),
                    ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.deleteStop),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 장소 줄 왼쪽 마커 그림의 폭. 아래 칸과 구간 줄을 이 폭에 맞춰 들인다.
final _iconWidth = MarkerIcon.size.width;

/// 외부 지도로 가는 작은 글자 링크. 바탕 없이 글자와 아이콘만 있어서 장소 줄보다 눈에 덜 띈다.
class _OpenMapLink extends StatelessWidget {
  const _OpenMapLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Padding(
        // 글자는 작아도 누르는 영역은 손가락 크기만큼 둔다.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                context.l10n.itineraryOpenNaverMap,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: scheme.primary),
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.open_in_new, size: 14, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// 장소 줄 사이의 구간 줄. 세로선은 도착 장소 쪽 선과 같은 색이다.
class ItinerarySegmentTile extends StatelessWidget {
  const ItinerarySegmentTile({
    super.key,
    required this.segment,
    required this.color,
    required this.highlighted,
    required this.onTap,
  });

  final Segment segment;
  final Color color;

  /// 고른 구간. 지도에서 선을 누르거나 시트에서 이 줄을 누른 것이다.
  final bool highlighted;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final transport = l10n.transportText(segment);
    return Material(
      color: highlighted ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: Row(
            children: [
              SizedBox(
                width: _iconWidth,
                height: AppSpace.xxl,
                child: Center(
                  child: Container(
                    width: AppSpace.xs,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppRadius.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  transport.isEmpty
                      ? l10n.itineraryTransportUndecided
                      : transport,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

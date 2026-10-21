import 'package:flutter/material.dart';

import '../../../core/map/map_provider.dart';
import '../../../core/map/marker_icon.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/segment.dart';
import '../../../data/models/stop.dart';
import '../../../l10n/l10n.dart';
import '../transport_look.dart';

/// 일차 동선 시트의 장소 줄.
///
/// 이름 쪽을 누르면 고르고 펼쳐져서 설명 전체와 메모가 나온다.
/// 오른쪽 연필 아이콘을 누르면 장소 입력 화면이 열린다. 지우기도 그 화면 안에 있다
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
    this.onEdit,
    this.caption,
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

  /// 연필 아이콘을 눌렀다. 장소 입력 화면을 연다. null이면 연필이 없다(목록에서 누른 줄에만 뜬다).
  final VoidCallback? onEdit;

  /// 이름 위의 작은 글자. 예: 출발 숙소 표시.
  final String? caption;

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
                    if (onEdit case final onEdit?)
                      _EditButton(
                        tooltip: l10n.stopFormEditTitle,
                        onPressed: onEdit,
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
          ],
        ),
      ),
    );
  }
}

/// 장소 줄 왼쪽 마커 그림의 폭. 아래 칸과 구간 줄을 이 폭에 맞춰 들인다.
final _iconWidth = MarkerIcon.size.width;

/// 구간 줄에서 토막과 "+" 사이 간격. 글자 사이 띄어쓰기 한 칸쯤이다.
const _chunkGap = AppSpace.xs;

/// 구간 줄의 토막 하나: 수단 아이콘과 토막 글자. 줄이 바뀌어도 둘이 떨어지거나 글자가 중간에 끊기지 않는다.
///
/// 토막 사이의 "+"는 따로 한 덩어리라서, 줄은 토막과 "+" 사이 어디서든 바뀐다.
/// 토막 하나가 줄보다 길 때만(아주 좁은 화면) 토막 안에서 줄이 바뀐다.
class _LegChunk extends StatelessWidget {
  const _LegChunk({
    required this.icon,
    required this.text,
    required this.color,
    required this.style,
  });

  final IconData icon;
  final String text;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: AppSpace.xs),
        child: Icon(icon, size: 16, color: color),
      ),
      Flexible(child: Text(text, style: style)),
    ],
  );
}

/// 장소 줄과 구간 줄 오른쪽의 연필 아이콘. 줄보다 눈에 덜 띄게 작고 흐리다.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    icon: Icon(
      Icons.edit_outlined,
      size: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    onPressed: onPressed,
  );
}

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
///
/// 토막마다 수단 아이콘과 글자를 잇는다. 예: [지하철] 지하철 2정류장 + [도보] 도보.
/// 줄을 누르면 고르기만 하고, 오른쪽 연필 아이콘을 눌러야 이동 수단 입력 화면이 열린다.
class ItinerarySegmentTile extends StatelessWidget {
  const ItinerarySegmentTile({
    super.key,
    required this.segment,
    required this.color,
    required this.highlighted,
    required this.onTap,
    this.onEdit,
  });

  final Segment segment;
  final Color color;

  /// 고른 구간. 지도에서 선을 누르거나 시트에서 이 줄을 누른 것이다.
  final bool highlighted;

  /// 줄을 눌렀다. 고르기만 한다.
  final VoidCallback onTap;

  /// 연필 아이콘을 눌렀다. 이동 수단 입력 화면을 연다. null이면 연필이 없다(목록에서 누른 줄에만 뜬다).
  final VoidCallback? onEdit;

  /// 갈아타는 토막이 많아 글자가 여러 줄이 될 때 줄 사이를 띄운다. 줄마다 수단 아이콘이 있어서
  /// 글자 기본 줄 높이로는 위아래 아이콘과 글자가 붙어 보인다.
  static const _lineHeight = 2.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: muted, height: _lineHeight);
    final legs = segment.legs;
    return Material(
      color: highlighted ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          // 갈아타는 토막이 많아 글자가 두 줄이 되어도 세로선이 줄 높이를 채운다.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _iconWidth,
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
                  child: ConstrainedBox(
                    // 연필 아이콘(작게 줄인 버튼, 40px)이 떠도 줄 높이가 바뀌지 않게 그만큼 둔다.
                    constraints: const BoxConstraints(
                      minHeight: AppSpace.xxl + AppSpace.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: legs.isEmpty
                          ? Text(l10n.itineraryTransportUndecided, style: style)
                          // 토막(아이콘 + "지하철 3정류장 10분")과 "+"를 각각 한 덩어리로 두고, 덩어리 사이에서만 줄을 바꾼다.
                          : Wrap(
                              spacing: _chunkGap,
                              children: [
                                for (final (i, leg) in legs.indexed) ...[
                                  if (i > 0)
                                    Text(
                                      l10n.transportLegSeparator.trim(),
                                      style: style,
                                    ),
                                  _LegChunk(
                                    icon: transportIcon(leg.mode),
                                    text: l10n.transportLegText(leg),
                                    color: muted,
                                    style: style,
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
                if (onEdit case final onEdit?)
                  Center(
                    child: _EditButton(
                      tooltip: l10n.itineraryEditTransport,
                      onPressed: onEdit,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

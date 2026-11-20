import 'package:flutter/material.dart';

import '../../../core/map/map_provider.dart';
import '../../../core/map/marker_icon.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/zoned_time.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/candidate.dart';
import '../../../data/models/segment.dart';
import '../../../data/models/stop.dart';
import '../../../l10n/l10n.dart';
import '../transport_look.dart';
import 'stop_photo.dart';

/// 일차 동선 시트의 장소 줄.
///
/// 이름 쪽을 누르면 고르고 펼쳐져서 설명 전체와 메모, 주소, 외부 지도 칸이 나온다.
/// 오른쪽 연필 아이콘을 누르면 장소 입력 화면이 열린다. 지우기도 그 화면 안에 있다
/// 외부 지도 칸을 누르면 네이버 지도에서 장소를 연다. 영업시간, 리뷰는 거기서 본다.
/// 그 칸은 펼친 줄에만 둔다. 방문 동그라미는 여행 중과 후에 연필 앞에 늘 있다
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
    this.saving = false,
    this.onVisit,
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

  /// 이름 위의 작은 글자. 예: 출발 장소 표시.
  final String? caption;

  /// 끌어서 순서를 바꾸는 손잡이. null이면 옮길 수 없다.
  final Widget? reorderHandle;

  /// 끌어 옮기고 저장을 기다리는 중. 흐리게 보이고, 연필과 손잡이 자리에 진행 표시가 뜬다.
  final bool saving;

  /// 방문 동그라미를 눌렀다(방문 전이면 기록, 방문했으면 지우기). 확인 창은 부른 쪽이 띄운다.
  /// null이면 동그라미가 없다(여행 전, 샘플, 출발 장소).
  final VoidCallback? onVisit;

  /// 사진 썸네일 크기. 누르면 크게 본다(줄 누르기와 따로).
  static const _photoSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final kind = l10n.stopKindName(stop.kind);
    final material = MaterialLocalizations.of(context);
    String format(LocalTime time) => material.formatTimeOfDay(
      TimeOfDay(hour: time.hour, minute: time.minute),
    );
    final time = stop.plannedTime;
    // 방문 시각은 장소 현지 시각이다(기기 시간대가 아니다).
    final visit = switch (stop.visitedAt) {
      final at? => format(zonedParts(at, stop.timeZone).time),
      null => null,
    };
    final kindLine = switch ((time, visit)) {
      (null, null) => kind,
      (final time?, null) => l10n.itineraryKindAndTime(kind, format(time)),
      (null, final visit?) => l10n.itineraryKindAndVisit(kind, visit),
      (final time?, final visit?) => l10n.itineraryKindTimeAndVisit(
        kind,
        format(time),
        visit,
      ),
    };
    final description = stop.description.trim();
    final memo = stop.memo.trim();
    final address = stop.address.trim();
    final opacity = saving ? AppOpacity.pending : 1.0;

    return Material(
      color: highlighted ? scheme.surfaceContainerHigh : Colors.transparent,
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
                    Opacity(opacity: opacity, child: MarkerIcon(look)),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Opacity(
                        opacity: opacity,
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
                            Text(kindLine, style: muted),
                            if (description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpace.xs,
                                ),
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
                            if (expanded && address.isNotEmpty)
                              _AddressLine(address),
                          ],
                        ),
                      ),
                    ),
                    if (stop.photo case final photo?)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpace.sm),
                        child: Opacity(
                          opacity: opacity,
                          child: StopPhotoThumbnail(
                            photo,
                            size: _photoSize,
                            label: l10n.stopPhotoLabel(stop.name),
                            onTap: () => showStopPhoto(
                              context,
                              photo: photo,
                              label: l10n.stopPhotoLabel(stop.name),
                            ),
                          ),
                        ),
                      ),
                    if (saving)
                      SavingIndicator(label: l10n.saving)
                    else ...[
                      if (onVisit case final onVisit?)
                        _VisitCheck(
                          visited: stop.visited,
                          tooltip: l10n.visitCheckTooltip(stop.name),
                          onPressed: onVisit,
                        ),
                      if (onEdit case final onEdit?)
                        _EditButton(
                          tooltip: l10n.stopFormEditTitle,
                          onPressed: onEdit,
                        ),
                      ?reorderHandle,
                    ],
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: EdgeInsets.only(
                  left: AppSpace.sm + _iconWidth + AppSpace.md - AppSpace.xs,
                  right: AppSpace.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: opacity,
                    child: _OpenMapLink(onTap: onOpenMap),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 장소 줄 오른쪽의 방문 동그라미. 방문 전에는 빈 원, 방문하면 채운 ✓다.
///
/// 펼치지 않아도 보이고 누를 수 있다. 누르면 부른 쪽이 확인 창을 띄운다.
class _VisitCheck extends StatelessWidget {
  const _VisitCheck({
    required this.visited,
    required this.tooltip,
    required this.onPressed,
  });

  final bool visited;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      checked: visited,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        isSelected: visited,
        icon: Icon(Icons.radio_button_unchecked, color: scheme.outline),
        selectedIcon: Icon(Icons.check_circle, color: scheme.primary),
        onPressed: onPressed,
      ),
    );
  }
}

/// 후보 목록의 후보 줄. 장소 줄과 모양이 같지만 일차·예정 시각·구간이 없다.
///
/// 누르면 고르고 펼쳐져서 설명 전체와 메모, [actions](예: [동선에 넣기]), 외부 지도 칸이 나온다.
/// 오른쪽 연필 아이콘은 목록에서 누른 줄에만 뜬다. 외부 지도 칸을 누르면 네이버 지도에서 연다.
class CandidateTile extends StatelessWidget {
  const CandidateTile({
    super.key,
    required this.candidate,
    required this.look,
    required this.expanded,
    required this.highlighted,
    required this.onToggle,
    required this.onOpenMap,
    this.onEdit,
    this.actions,
    this.distance,
  });

  final Candidate candidate;

  /// 현재 위치에서의 직선거리 글자(예: 350m). 줄 오른쪽에 작게 보인다. 위치를 모르면 null이다.
  final String? distance;

  /// 지도의 후보 마커와 같은 그림.
  final MarkerLook look;

  final bool expanded;
  final bool highlighted;
  final VoidCallback onToggle;
  final VoidCallback onOpenMap;

  /// 연필 아이콘을 눌렀다. 후보 입력 화면을 연다. null이면 연필이 없다.
  final VoidCallback? onEdit;

  /// 펼쳤을 때 설명·메모 아래에 두는 버튼들. null이면 없다(보기만 하는 샘플).
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final description = candidate.description.trim();
    final memo = candidate.memo.trim();
    final address = candidate.address.trim();
    final actions = this.actions;
    // 글자 줄과 첫 글자를 맞춘다.
    final textStart = AppSpace.sm + _iconWidth + AppSpace.md;

    return Material(
      color: highlighted ? scheme.surfaceContainerHigh : Colors.transparent,
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
                    // 장소 줄의 큰 마커와 글자 자리를 맞춘다.
                    SizedBox.fromSize(
                      size: MarkerIcon.size,
                      child: Center(child: MarkerIcon(look)),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.name,
                            style: textTheme.titleSmall,
                            maxLines: expanded ? null : 1,
                            overflow: expanded ? null : TextOverflow.ellipsis,
                          ),
                          Text(l10n.stopKindName(candidate.kind), style: muted),
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
                          if (expanded && address.isNotEmpty)
                            _AddressLine(address),
                        ],
                      ),
                    ),
                    if (distance case final distance?)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpace.sm),
                        child: Text(distance, style: muted),
                      ),
                    if (onEdit case final onEdit?)
                      _EditButton(
                        tooltip: l10n.candidateEditTooltip,
                        onPressed: onEdit,
                      ),
                  ],
                ),
              ),
            ),
            if (expanded && actions != null)
              Padding(
                padding: EdgeInsets.only(
                  left: textStart,
                  right: AppSpace.sm,
                  top: AppSpace.xs,
                ),
                child: Align(alignment: Alignment.centerLeft, child: actions),
              ),
            if (expanded)
              Padding(
                // 링크 자체의 안쪽 여백만큼 덜 들인다.
                padding: EdgeInsets.only(
                  left: textStart - AppSpace.xs,
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

/// 구간 줄 왼쪽의 세로선. 지도의 선 모양(실선·파선·점선)을 세로로 줄여 그린다.
class _RouteBarPainter extends CustomPainter {
  _RouteBarPainter({required this.color, required this.style});

  final Color color;
  final MapLineStyle style;

  /// 파선 한 토막과 빈칸.
  static const _dash = AppSpace.sm;
  static const _dashGap = AppSpace.xs;

  /// 점 사이 간격(점 중심끼리). 점 지름은 선 두께다.
  static const _dotStep = AppSpace.sm;

  /// 가는 파선(숙소를 거침)의 토막. 빈칸도 같은 길이다.
  static const _faintDash = AppSpace.xs;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final width = size.width;
    final radius = Radius.circular(width / 2);
    switch (style) {
      case MapLineStyle.solid:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & size, radius),
          paint,
        );
      case MapLineStyle.dashed:
        for (var y = 0.0; y < size.height; y += _dash + _dashGap) {
          final end = (y + _dash).clamp(0.0, size.height);
          canvas.drawRRect(RRect.fromLTRBR(0, y, width, end, radius), paint);
        }
      case MapLineStyle.dotted:
        for (var y = width / 2; y < size.height; y += _dotStep) {
          canvas.drawCircle(Offset(width / 2, y), width / 2, paint);
        }
      case MapLineStyle.faint:
        // 지도처럼 가늘고 토막이 짧다. 굵기는 다른 선의 절반이다.
        final half = width / 4;
        for (var y = 0.0; y < size.height; y += _faintDash * 2) {
          final end = (y + _faintDash).clamp(0.0, size.height);
          canvas.drawRect(
            Rect.fromLTRB(width / 2 - half, y, width / 2 + half, end),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_RouteBarPainter old) =>
      old.color != color || old.style != style;
}

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

/// 펼친 장소·후보 줄의 주소. 이름만으로 어디인지 모를 때 보는 것이라 작고 흐리게, 외부 지도 링크 바로 위에 둔다.
class _AddressLine extends StatelessWidget {
  const _AddressLine(this.address);

  final String address;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // 아이콘을 첫 줄 글자 가운데에 맞춘다.
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.place_outlined,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              address,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// 구간 줄 맨 위 ⊕ 띠의 높이. 이동 수단 글자는 이 아래 줄에 놓는다.
const _insertBand = AppSpace.xl;

/// 이동 수단 미정 구간 줄의 높이(연필이 없을 때). 글자 한 줄(bodySmall × 줄 높이 2)이 들어간다.
const _undecidedHeight = AppSpace.xl;

/// 구간 줄 맨 위 세로선의 작은 ⊕.
class _InsertButton extends StatelessWidget {
  const _InsertButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.itineraryInsertHere,
    child: InkResponse(
      onTap: onPressed,
      radius: AppSpace.lg,
      child: SizedBox(
        width: _iconWidth,
        height: _insertBand,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_circle, size: 18, color: color),
          ),
        ),
      ),
    ),
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

/// 숙소를 끈 시트에서 낮에 들른 숙소를 건너 이은 자리에 두는 가는 줄. 지도의 "숙소를 거침" 선과 같은 무늬다.
///
/// 실제 구간이 아니라서 고르지 않고 연필도 없다. 숙소 이름은 쓰지 않는다(숙소를 끈 보기라서).
/// 누르면 [onTap]으로 숙소를 켜면 그 사이 이동 수단을 볼 수 있다고 알린다.
class ItineraryViaTile extends StatelessWidget {
  const ItineraryViaTile({super.key, required this.color, this.onTap});

  /// 세로선 색. 도착 장소의 일차 색을 흐리게 쓴다.
  final Color color;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        child: SizedBox(
          height: AppSpace.xl,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _iconWidth,
                child: Center(
                  child: SizedBox(
                    width: AppSpace.xs,
                    height: double.infinity,
                    child: CustomPaint(
                      painter: _RouteBarPainter(
                        color: color,
                        style: MapLineStyle.faint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.itineraryViaLodging,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
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
    this.onInsert,
    this.saving = false,
  });

  final Segment segment;
  final Color color;

  /// 곡선을 끌어 놓고 저장을 기다리는 중. 흐리게 보이고, 연필 자리에 진행 표시가 뜬다.
  final bool saving;

  /// 고른 구간. 지도에서 선을 누르거나 시트에서 이 줄을 누른 것이다.
  final bool highlighted;

  /// 줄을 눌렀다. 고르기만 한다.
  final VoidCallback onTap;

  /// 연필 아이콘을 눌렀다. 이동 수단 입력 화면을 연다. null이면 연필이 없다(목록에서 누른 줄에만 뜬다).
  final VoidCallback? onEdit;

  /// 세로선 위 ⊕를 눌렀다. 이 구간의 두 장소 사이에 넣을 곳을 찾는다. null이면 ⊕가 없다.
  /// 사이에 넣는 기능을 찾을 수 있게 고르지 않아도 늘 보인다(사용자 결정).
  final VoidCallback? onInsert;

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
    final opacity = saving ? AppOpacity.pending : 1.0;
    // 줄 높이를 다 채우는 세로선.
    Widget bar() => Center(
      child: SizedBox(
        width: AppSpace.xs,
        height: double.infinity,
        child: CustomPaint(
          painter: _RouteBarPainter(
            color: color,
            style: lineStyleOf(representativeMode(segment.legs)),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ⊕는 구간 줄 위(앞 장소 줄과의 경계)에 따로 둔다.
        if (onInsert case final onInsert? when !saving)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                key: const ValueKey('insertBand'),
                width: _iconWidth,
                height: _insertBand,
                child: Stack(
                  children: [
                    bar(),
                    _InsertButton(color: color, onPressed: onInsert),
                  ],
                ),
              ),
            ),
          ),
        Material(
          color: highlighted ? scheme.surfaceContainerHigh : Colors.transparent,
          borderRadius: AppRadius.md,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.md,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Opacity(
                      opacity: opacity,
                      child: SizedBox(width: _iconWidth, child: bar()),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Opacity(
                        opacity: opacity,
                        child: ConstrainedBox(
                          // 이동 수단 미정은 보일 것이 없어 낮게 두고, 눌러 연필이 뜰 때만 늘어난다
                          constraints: BoxConstraints(
                            minHeight: legs.isEmpty && onEdit == null && !saving
                                ? _undecidedHeight
                                : AppSpace.xxl + AppSpace.sm,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: legs.isEmpty
                                ? Text(
                                    l10n.itineraryTransportUndecided,
                                    style: style,
                                  )
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
                    ),
                    if (saving)
                      Center(child: SavingIndicator(label: l10n.saving))
                    else if (onEdit case final onEdit?)
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
        ),
      ],
    );
  }
}

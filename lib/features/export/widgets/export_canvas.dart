import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/map/map_provider.dart';
import '../../../core/map/marker_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../export_layout.dart';
import '../export_scene.dart';

/// 이름표 글자의 최대 폭(논리 px). 넘으면 말줄임표다.
const _labelMaxWidth = 140.0;

const _labelPadding = EdgeInsets.symmetric(
  horizontal: AppSpace.sm,
  vertical: AppSpace.xs / 2,
);

const _cardPadding = EdgeInsets.symmetric(
  horizontal: AppSpace.md,
  vertical: AppSpace.sm,
);

/// 제목 카드 범례의 일차 색 점 지름.
const _legendDot = 8.0;

// 선 굵기와 무늬는 앱 지도(네이버 구현)와 같다.
const _lineWidth = 5.0;
const _lineOutlineWidth = 1.5;
const _faintLineWidth = 3.0;
const _dashPattern = [12.0, 8.0];
const _dotPattern = [1.0, 11.0];
const _faintPattern = [6.0, 6.0];

/// 이미지 위 글자 모양과 자리. 지도를 맞추기 전(제목 카드 높이)과 그릴 때 같은 값을 쓴다.
///
/// 이미지는 기기 글자 크기 설정과 관계없이 같아야 해서 글자를 늘리지 않는다.
class ExportMetrics {
  ExportMetrics(BuildContext context, this.size)
    : _theme = Theme.of(context),
      _l10n = context.l10n;

  /// 이미지 크기(논리 px).
  final Size size;
  final ThemeData _theme;
  final AppLocalizations _l10n;

  TextStyle get titleStyle => _theme.textTheme.titleMedium!.copyWith(
    color: _theme.colorScheme.onSurface,
  );

  TextStyle get subtitleStyle => _theme.textTheme.bodySmall!.copyWith(
    color: _theme.colorScheme.onSurfaceVariant,
  );

  TextStyle get legendStyle => _theme.textTheme.labelSmall!.copyWith(
    color: _theme.colorScheme.onSurfaceVariant,
  );

  TextStyle get labelStyle => _theme.textTheme.labelMedium!.copyWith(
    color: _theme.colorScheme.onSurface,
  );

  TextStyle get watermarkStyle => _theme.textTheme.labelSmall!.copyWith(
    color: _theme.colorScheme.onSurfaceVariant,
  );

  static Size _measure(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final measured = painter.size;
    painter.dispose();
    return measured;
  }

  /// 장소 이름표 크기.
  Size labelSize(String name) {
    final text = _measure(name, labelStyle, _labelMaxWidth);
    return Size(
      text.width + _labelPadding.horizontal,
      text.height + _labelPadding.vertical,
    );
  }

  double get _cardMaxWidth => size.width - AppSpace.md * 2;

  double get _legendHeight =>
      math.max(_legendDot, _measure('1', legendStyle, double.infinity).height);

  double _legendWidth(List<int> days) => days.isEmpty
      ? 0
      : [
              for (final day in days)
                _legendDot +
                    AppSpace.xs +
                    _measure(
                      _l10n.routeDay(day),
                      legendStyle,
                      double.infinity,
                    ).width,
            ].reduce((a, b) => a + b) +
            AppSpace.sm * (days.length - 1);

  /// 제목 카드가 놓이는 곳. 제목을 끄면 null이다.
  Rect? titleCardRect(ExportScene scene) {
    final title = scene.title;
    if (title == null) return null;
    final inner = _cardMaxWidth - _cardPadding.horizontal;
    final titleSize = _measure(title, titleStyle, inner);
    final subtitleSize = _measure(scene.subtitle, subtitleStyle, inner);
    final legend = scene.legendDays;
    final width = [
      titleSize.width,
      subtitleSize.width,
      _legendWidth(legend),
    ].reduce(math.max);
    final height =
        titleSize.height +
        AppSpace.xs / 2 +
        subtitleSize.height +
        (legend.isEmpty ? 0 : AppSpace.xs + _legendHeight);
    return Rect.fromLTWH(
      AppSpace.md,
      AppSpace.md,
      math.min(_cardMaxWidth, width + _cardPadding.horizontal),
      height + _cardPadding.vertical,
    );
  }

  /// 오른쪽 아래 앱 이름이 놓이는 곳.
  Rect get watermarkRect {
    final text = _measure(_l10n.exportWatermark, watermarkStyle, size.width);
    final width = text.width + _labelPadding.horizontal;
    final height = text.height + _labelPadding.vertical;
    return Rect.fromLTWH(
      size.width - AppSpace.md - width,
      size.height - AppSpace.md - height,
      width,
      height,
    );
  }
}

/// 내보내기 이미지 한 장. 찍은 지도 위에 동선, 마커, 이름표, 제목 카드, 앱 이름을 그리고 지도 로고를 다시 덮는다.
///
/// 이 위젯을 그대로 이미지로 바꿔 저장한다(RepaintBoundary). 크기는 [ExportMetrics.size]다.
class ExportCanvas extends StatelessWidget {
  const ExportCanvas({
    super.key,
    required this.capture,
    required this.scene,
    required this.metrics,
  });

  final MapCapture capture;
  final ExportScene scene;
  final ExportMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final card = metrics.titleCardRect(scene);
    final watermark = metrics.watermarkRect;
    final layout = layoutExport(
      scene: scene,
      projection: capture.projection,
      size: metrics.size,
      reserved: [?card, watermark, capture.logo],
      labelSize: metrics.labelSize,
    );
    // 사진 마커는 크고 네모라 옆 장소를 덮기 쉽다. 먼저 그려서 번호 마커가 늘 위에 보이게 한다(동선 순서가 먼저다).
    final markers = [
      ...layout.markers.where((m) => m.marker.look.photo != null),
      ...layout.markers.where((m) => m.marker.look.photo == null),
    ];
    return SizedBox.fromSize(
      size: metrics.size,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: RawImage(image: capture.image, fit: BoxFit.fill),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _LinesPainter(layout.lines)),
            ),
            for (final (arrow, at) in layout.arrows)
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: at,
                  width: ArrowIcon.size.width,
                  height: ArrowIcon.size.height,
                ),
                child: Transform.rotate(
                  angle: arrow.bearing * math.pi / 180,
                  child: ArrowIcon(color: arrow.color, outline: arrow.outline),
                ),
              ),
            for (final (icon, at) in layout.lineIcons)
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: at,
                  width: LineIconBadge.size.width,
                  height: LineIconBadge.size.height,
                ),
                child: LineIconBadge(icon),
              ),
            for (final placed in markers)
              Positioned.fromRect(
                rect: placed.rect,
                child: FittedBox(child: MarkerIcon(placed.marker.look)),
              ),
            for (final label in layout.labels)
              Positioned.fromRect(
                rect: label.rect,
                child: _Pill(
                  text: label.marker.name,
                  style: metrics.labelStyle,
                  color: scheme.surfaceContainerLowest,
                ),
              ),
            if (card != null)
              Positioned.fromRect(
                rect: card,
                child: _TitleCard(scene: scene, metrics: metrics),
              ),
            Positioned.fromRect(
              rect: watermark,
              child: _Pill(
                text: context.l10n.exportWatermark,
                style: metrics.watermarkStyle,
                color: colors.routeHalo,
              ),
            ),
            // 지도 로고는 가리면 안 된다. 그 자리를 찍은 지도로 다시 덮는다.
            Positioned.fill(
              child: CustomPaint(
                painter: _PatchPainter(
                  capture.image,
                  capture.logo,
                  capture.image.width / metrics.size.width,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.style, required this.color});

  final String text;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, borderRadius: AppRadius.sm),
    child: Padding(
      padding: _labelPadding,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.scene, required this.metrics});

  final ExportScene scene;
  final ExportMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.lg,
        border: Border.all(color: colors.cardBorder),
      ),
      child: Padding(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scene.title!,
              style: metrics.titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpace.xs / 2),
            Text(
              scene.subtitle,
              style: metrics.subtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (scene.legendDays.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  for (final (i, day) in scene.legendDays.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpace.sm),
                    Container(
                      width: _legendDot,
                      height: _legendDot,
                      decoration: BoxDecoration(
                        color: colors.routeDay(day).background,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      context.l10n.routeDay(day),
                      style: metrics.legendStyle,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 선. 앱 지도처럼 흰 테두리 위에 일차 색 선을 그린다. 흐린 연결선([MapLineStyle.faint])은 테두리 없이 가늘다.
class _LinesPainter extends CustomPainter {
  const _LinesPainter(this.lines);

  final List<(MapLine, List<Offset>)> lines;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (line, points) in lines) {
      if (points.length < 2) continue;
      final path = Path()..addPolygon(points, false);
      if (line.style == MapLineStyle.faint) {
        _stroke(
          canvas,
          path,
          line.color,
          _faintLineWidth,
          pattern: _faintPattern,
        );
        continue;
      }
      final pattern = switch (line.style) {
        MapLineStyle.dashed => _dashPattern,
        MapLineStyle.dotted => _dotPattern,
        _ => null,
      };
      final round = line.style != MapLineStyle.dashed;
      _stroke(
        canvas,
        path,
        line.outline,
        _lineWidth + _lineOutlineWidth * 2,
        pattern: pattern,
        round: round,
      );
      _stroke(
        canvas,
        path,
        line.color,
        _lineWidth,
        pattern: pattern,
        round: round,
      );
    }
  }

  void _stroke(
    Canvas canvas,
    Path path,
    Color color,
    double width, {
    List<double>? pattern,
    bool round = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;
    canvas.drawPath(pattern == null ? path : _dashed(path, pattern), paint);
  }

  /// [pattern](그리는 길이, 빈칸 길이)대로 끊은 선.
  static Path _dashed(Path path, List<double> pattern) {
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var i = 0;
      while (distance < metric.length) {
        final length = pattern[i % pattern.length];
        if (i.isEven) {
          dashed.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        i++;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.lines != lines;
}

/// 찍은 지도의 [rect] 자리(논리 px)를 그대로 다시 그린다.
class _PatchPainter extends CustomPainter {
  const _PatchPainter(this.image, this.rect, this.pixelRatio);

  final ui.Image image;
  final Rect rect;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTRB(
      rect.left * pixelRatio,
      rect.top * pixelRatio,
      rect.right * pixelRatio,
      rect.bottom * pixelRatio,
    );
    canvas.drawImageRect(image, source, rect, Paint());
  }

  @override
  bool shouldRepaint(_PatchPainter old) =>
      old.image != image || old.rect != rect || old.pixelRatio != pixelRatio;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'route_geometry.dart';

/// 지도 스냅샷 위에 동선(곡선, 화살표, 장소 이름)과 제목을 그린다.
///
/// [points]는 스냅샷 이미지의 픽셀 좌표, [scale]은 논리 픽셀 1개당 이미지 픽셀 수다.
Future<ui.Image> composeRoute({
  required ui.Image base,
  required List<Offset> points,
  required List<String> names,
  required String title,
  required double scale,
  double curvature = 0.2,
}) async {
  final width = base.width.toDouble();
  final height = base.height.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

  canvas.drawImage(base, Offset.zero, Paint());

  final linePaint = Paint()
    ..color = const Color(0xFF1E6FFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4 * scale
    ..strokeCap = StrokeCap.round;
  final arrowPaint = Paint()..color = const Color(0xFF1E6FFF);

  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    // 구간마다 휘는 방향을 번갈아 바꿔 곡선이 잘 보이게 한다.
    final c = quadraticControlPoint(a, b, i.isEven ? curvature : -curvature);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy),
      linePaint,
    );
    _drawArrow(
      canvas,
      quadraticPoint(a, c, b, 0.5),
      quadraticTangent(a, c, b, 0.5),
      8 * scale,
      arrowPaint,
    );
  }

  for (var i = 0; i < points.length; i++) {
    canvas.drawCircle(points[i], 7 * scale, Paint()..color = Colors.white);
    canvas.drawCircle(
      points[i],
      5 * scale,
      Paint()..color = const Color(0xFF1E6FFF),
    );
    _drawLabel(canvas, '${i + 1}. ${names[i]}', points[i], scale);
  }

  _drawTitle(canvas, title, width, scale);

  final picture = recorder.endRecording();
  return picture.toImage(base.width, base.height);
}

void _drawArrow(
  Canvas canvas,
  Offset at,
  Offset tangent,
  double size,
  Paint paint,
) {
  final angle = math.atan2(tangent.dy, tangent.dx);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(angle);
  canvas.drawPath(
    Path()
      ..moveTo(size, 0)
      ..lineTo(-size, -size * 0.8)
      ..lineTo(-size, size * 0.8)
      ..close(),
    paint,
  );
  canvas.restore();
}

void _drawLabel(Canvas canvas, String text, Offset point, double scale) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontSize: 13 * scale,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final padding = 4 * scale;
  final topLeft = point + Offset(10 * scale, -painter.height / 2 - padding);
  final rect = Rect.fromLTWH(
    topLeft.dx,
    topLeft.dy,
    painter.width + padding * 2,
    painter.height + padding * 2,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
    Paint()..color = Colors.white.withValues(alpha: 0.9),
  );
  painter.paint(canvas, topLeft + Offset(padding, padding));
}

void _drawTitle(Canvas canvas, String title, double width, double scale) {
  final painter = TextPainter(
    text: TextSpan(
      text: title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 22 * scale,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 32 * scale);
  final bandHeight = painter.height + 24 * scale;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, bandHeight),
    Paint()..color = Colors.black.withValues(alpha: 0.55),
  );
  painter.paint(canvas, Offset(16 * scale, 12 * scale));
}

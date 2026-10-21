import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'map_provider.dart';

/// 마커 그림. 지도 구현이 이 위젯을 이미지로 바꿔 지도에 올린다.
///
/// 원의 가운데가 그림의 가운데라서, 마커의 기준점은 그림 가운데다.
class MarkerIcon extends StatelessWidget {
  const MarkerIcon(this.look, {super.key});

  /// 원(지름 [_circle])과, 원 오른쪽 위에 걸친 배지(지름 [_badge])가 들어가는 크기.
  static const size = Size.square(36);

  static const _circle = 28.0;
  static const _border = 2.0;
  static const _badge = 16.0;

  final MarkerLook look;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: AppFont.extraBold,
      color: look.foreground,
      height: 1,
    );
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: _circle,
            height: _circle,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: look.fill,
              shape: BoxShape.circle,
              border: Border.all(color: look.halo, width: _border),
            ),
            child: switch (look) {
              MarkerLook(:final label?) => Text(label, style: labelStyle),
              MarkerLook(:final icon?) => Icon(
                icon,
                size: 16,
                color: look.foreground,
              ),
              _ => null,
            },
          ),
          if (look.badge case final badge?)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: _badge,
                height: _badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: look.halo,
                  shape: BoxShape.circle,
                  border: Border.all(color: look.fill),
                ),
                child: Icon(badge, size: 11, color: look.foreground),
              ),
            ),
        ],
      ),
    );
  }
}

/// 선 아이콘 그림(예: 이동 수단). 둥근 네모라서 둥근 원인 장소 마커와 구분된다.
///
/// 흰 바탕([MapLineIcon.background])에 선 색 테두리, 그 위에 아이콘이다. 장소 마커보다 작다.
class LineIconBadge extends StatelessWidget {
  const LineIconBadge(this.lineIcon, {super.key});

  static const size = Size.square(22);
  static const _border = 2.0;
  static const _icon = 14.0;

  final MapLineIcon lineIcon;

  @override
  Widget build(BuildContext context) => Container(
    width: size.width,
    height: size.height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: lineIcon.background,
      borderRadius: AppRadius.sm,
      border: Border.all(color: lineIcon.border, width: _border),
    ),
    child: Icon(lineIcon.icon, size: _icon, color: lineIcon.foreground),
  );
}

/// 진행 방향 화살표 그림. 위(북쪽)를 가리키고, 지도 구현이 구간 방향만큼 돌린다.
///
/// 뒤가 오목한 화살촉 모양이다. 테두리를 둘러 같은 색 선 위에서도 모양이 보인다.
class ArrowIcon extends StatelessWidget {
  const ArrowIcon({super.key, required this.color, required this.outline});

  static const size = Size.square(18);

  final Color color;
  final Color outline;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: size,
    painter: _ArrowPainter(color: color, outline: outline),
  );
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color, required this.outline});

  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.88, h * 0.86)
      ..lineTo(w * 0.5, h * 0.66)
      ..lineTo(w * 0.12, h * 0.86)
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.color != color || old.outline != outline;
}

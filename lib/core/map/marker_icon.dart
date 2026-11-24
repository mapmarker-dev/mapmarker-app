import 'package:flutter/material.dart';

import '../../data/models/photo.dart';
import '../theme/app_tokens.dart';
import 'map_provider.dart';

/// 마커 그림. 지도 구현이 이 위젯을 이미지로 바꿔 지도에 올린다.
///
/// 원의 가운데가 그림의 가운데라서, 마커의 기준점은 그림 가운데다.
/// 사진 마커([MarkerLook.photo])는 꼬리 끝이 기준점이다([anchorOf]).
class MarkerIcon extends StatelessWidget {
  const MarkerIcon(this.look, {super.key});

  /// 원(지름 [_circle])과, 원 오른쪽 위에 걸친 배지(지름 [_badge])가 들어가는 크기.
  static const size = Size.square(32);

  /// 작은 마커([MarkerLook.small])의 크기. 배지 없이 원(지름 [_smallCircle])만 들어간다.
  static const smallSize = Size.square(22);

  /// 사진 마커의 크기. 사진(정사각형)과 꼬리, 장소에서 먼 쪽 모서리로 걸친 번호 원이 들어간다.
  /// 꼬리 양옆을 똑같이 비워 꼬리 끝이 그 변의 가운데에 온다. 사진이 위·아래면 세로, 왼쪽·오른쪽이면 가로로 길다.
  static Size photoSizeOf(PhotoSide side) => switch (side) {
    PhotoSide.up || PhotoSide.down => const Size(
      _photoInset * 2 + _photo,
      _photoInset + _photo + _tail,
    ),
    PhotoSide.left || PhotoSide.right => const Size(
      _photoInset + _photo + _tail,
      _photoInset * 2 + _photo,
    ),
  };

  /// [look] 그림의 크기. 지도 구현이 마커 크기로 쓴다.
  static Size sizeOf(MarkerLook look) => look.photo != null
      ? photoSizeOf(look.photoSide)
      : look.small
      ? smallSize
      : size;

  /// 장소 자리가 그림의 어디인지(가로, 세로 0~1). 원은 가운데, 사진 마커는 꼬리 끝이다
  /// (사진이 위면 아래 가운데, 아래면 위 가운데, 왼쪽이면 오른쪽 가운데, 오른쪽이면 왼쪽 가운데).
  static Offset anchorOf(MarkerLook look) => look.photo == null
      ? const Offset(0.5, 0.5)
      : switch (look.photoSide) {
          PhotoSide.up => const Offset(0.5, 1),
          PhotoSide.down => const Offset(0.5, 0),
          PhotoSide.left => const Offset(1, 0.5),
          PhotoSide.right => const Offset(0, 0.5),
        };

  static const _circle = 24.0;
  static const _smallCircle = 18.0;
  static const _border = 2.0;
  static const _badge = 14.0;

  /// 사진 마커: 사진 한 변(테두리 포함), 테두리 두께, 꼬리 높이, 번호 원 지름.
  static const _photo = 40.0;
  static const _photoBorder = 3.0;
  static const _tail = 7.0;
  static const _number = 18.0;
  static const _photoHalo = 1.5;

  /// 번호 원이 사진 모서리에 걸치도록 사진을 안으로 들인 거리.
  static const _photoInset = _number / 3;

  /// 사진 마커가 장소 자리에서 사진 쪽으로 뻗는 길이(꼬리와 사진과 번호 원 여백). 방향과 관계없이 같다.
  static const photoReach = _photoInset + _photo + _tail;

  final MarkerLook look;

  @override
  Widget build(BuildContext context) {
    if (look.photo case final photo?) return _buildPhoto(context, photo);
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: AppFont.extraBold,
      color: look.foreground,
      height: 1,
    );
    final circle = look.small ? _smallCircle : _circle;
    return SizedBox.fromSize(
      size: sizeOf(look),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: circle,
            height: circle,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: look.fill,
              shape: BoxShape.circle,
              border: Border.all(color: look.ring ?? look.halo, width: _border),
            ),
            child: switch (look) {
              MarkerLook(:final label?) => Text(label, style: labelStyle),
              MarkerLook(:final icon?) => Icon(
                icon,
                size: look.small ? 11 : 14,
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
                child: Icon(badge, size: 10, color: look.foreground),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoto(BuildContext context, ImageProvider photo) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontSize: 11,
      fontWeight: AppFont.extraBold,
      color: look.foreground,
      height: 1,
    );
    final frame = look.photoFrame ?? look.fill;
    final side = look.photoSide;
    final box = photoSizeOf(side);
    const strip = _tail + _photoBorder;
    // 사진이 놓이는 곳, 꼬리 띠(사진 테두리에 조금 겹친다), 꼬리를 돌릴 횟수(아래를 가리키는 꼬리에서 시계 방향 90도씩),
    // 번호 원의 자리(장소에서 먼 쪽 모서리. 장소 둘레에 모이는 선과 화살표를 가리지 않는다).
    final (photoAt, tailRect, turns, numberAt) = switch (side) {
      PhotoSide.up => (
        const Offset(_photoInset, _photoInset),
        Rect.fromLTWH(0, box.height - strip, box.width, strip),
        0,
        Offset.zero,
      ),
      PhotoSide.down => (
        const Offset(_photoInset, _tail),
        Rect.fromLTWH(0, 0, box.width, strip),
        2,
        Offset(0, box.height - _number),
      ),
      PhotoSide.left => (
        const Offset(_photoInset, _photoInset),
        Rect.fromLTWH(box.width - strip, 0, strip, box.height),
        3,
        Offset.zero,
      ),
      PhotoSide.right => (
        const Offset(_tail, _photoInset),
        Rect.fromLTWH(0, 0, strip, box.height),
        1,
        Offset(box.width - _number, 0),
      ),
    };
    // 꼬리: 사진 변의 가운데에서 장소 자리를 가리킨다.
    // 흰 테두리 꼬리를 사진 아래에, 테두리 색 꼬리를 사진 위에 그려 사진과 꼬리 사이에 흰 줄이 생기지 않게 한다.
    Widget tail(Color color, {required double inset}) => Positioned.fromRect(
      rect: tailRect,
      child: RotatedBox(
        quarterTurns: turns,
        child: CustomPaint(painter: _TailPainter(color, inset: inset)),
      ),
    );
    return SizedBox.fromSize(
      size: box,
      child: Stack(
        children: [
          tail(look.halo, inset: 0),
          Positioned(
            left: photoAt.dx,
            top: photoAt.dy,
            width: _photo,
            height: _photo,
            child: Container(
              padding: const EdgeInsets.all(_photoBorder),
              // 흰 바깥 선이 같은 색의 동선과 마커를 떼어 놓는다(원 마커의 흰 테두리와 같다).
              decoration: BoxDecoration(
                color: frame,
                borderRadius: AppRadius.sm,
                border: Border.all(color: look.halo, width: _photoHalo),
              ),
              child: ClipRRect(
                borderRadius:
                    AppRadius.sm - BorderRadius.circular(_photoBorder),
                child: Image(image: photo, fit: BoxFit.cover),
              ),
            ),
          ),
          tail(frame, inset: _photoHalo),
          if (look.label != null || look.icon != null)
            Positioned(
              left: numberAt.dx,
              top: numberAt.dy,
              child: Container(
                width: _number,
                height: _number,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: look.fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: look.halo, width: 1.5),
                ),
                child: switch (look) {
                  MarkerLook(:final label?) => Text(label, style: labelStyle),
                  MarkerLook(:final icon?) => Icon(
                    icon,
                    size: 11,
                    color: look.foreground,
                  ),
                  _ => null,
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 사진 마커의 꼬리(아래를 가리키는 삼각형).
/// [inset]만큼 안쪽(좌우와 끝)으로 줄여 그린다. 흰 테두리 꼬리 위에 줄인 꼬리를 겹쳐 테두리를 만든다.
class _TailPainter extends CustomPainter {
  const _TailPainter(this.color, {required this.inset});

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = 7.5 - inset;
    final middle = size.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(middle - halfWidth, 0)
        ..lineTo(middle + halfWidth, 0)
        ..lineTo(middle, size.height - inset * 1.5)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.inset != inset;
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

/// 곡선 핸들 그림. 흰 원 안에 진행 방향 화살표가 있다. 위(북쪽)를 가리키고, 지도 구현이 곡선 방향만큼 돌린다.
///
/// 화살표 자리(곡선 가운데)에 놓여서, 고른 구간의 화살표가 "잡을 수 있는 화살표"로 바뀐 것처럼 보인다.
class CurveHandleIcon extends StatelessWidget {
  const CurveHandleIcon({
    super.key,
    required this.color,
    required this.outline,
  });

  static const size = Size.square(32);
  static const _border = 2.5;

  final Color color;
  final Color outline;

  @override
  Widget build(BuildContext context) => Container(
    width: size.width,
    height: size.height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: outline,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: _border),
    ),
    child: ArrowIcon(color: color, outline: outline),
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

/// 사진 방향을 고르는 화살표 4개 그림. 그림 가운데가 장소 자리다.
///
/// 지금 방향([side])의 화살표는 사진 너머에 채워진 원으로, 나머지는 장소 가까이에 흰 원으로 그린다.
/// 지도 구현은 이 그림을 장소 자리에 올리고, 같은 자리([offsetOf])에 누르는 영역을 둔다.
class PhotoSideArrows extends StatelessWidget {
  const PhotoSideArrows({
    super.key,
    required this.side,
    required this.color,
    required this.outline,
  });

  /// 화살표 원 지름.
  static const arrow = 28.0;

  /// 사진이 없는 쪽 화살표의 장소 자리에서 거리. 원 마커 둘레 바로 밖이다.
  static const _near = 30.0;

  /// 지금 방향 화살표의 거리. 사진 바로 너머다.
  static const _far = MarkerIcon.photoReach + AppSpace.xs + arrow / 2;

  static const size = Size.square((_far + arrow / 2) * 2);

  /// [arrowSide] 화살표 가운데의 장소 자리에서 떨어진 거리(논리 px, 화면 기준). 지금 방향이 [current]다.
  static Offset offsetOf(PhotoSide arrowSide, PhotoSide current) {
    final d = arrowSide == current ? _far : _near;
    return switch (arrowSide) {
      PhotoSide.up => Offset(0, -d),
      PhotoSide.down => Offset(0, d),
      PhotoSide.left => Offset(-d, 0),
      PhotoSide.right => Offset(d, 0),
    };
  }

  final PhotoSide side;
  final Color color;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final center = size.center(Offset.zero);
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          for (final arrowSide in PhotoSide.values)
            Positioned.fromRect(
              rect: Rect.fromCenter(
                center: center + offsetOf(arrowSide, side),
                width: arrow,
                height: arrow,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: arrowSide == side ? color : outline,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: arrowSide == side ? outline : color,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  switch (arrowSide) {
                    PhotoSide.up => Icons.keyboard_arrow_up,
                    PhotoSide.down => Icons.keyboard_arrow_down,
                    PhotoSide.left => Icons.keyboard_arrow_left,
                    PhotoSide.right => Icons.keyboard_arrow_right,
                  },
                  size: 20,
                  color: arrowSide == side ? outline : color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

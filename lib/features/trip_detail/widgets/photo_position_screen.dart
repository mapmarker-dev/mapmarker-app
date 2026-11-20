import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';

/// "사진 위치" 화면을 띄운다. 정사각형 틀 안에 보일 부분을 고른다.
///
/// [확인]하면 고른 정사각형을 원본 폭과 높이에 대한 비율로 돌려주고, 닫으면 null이다.
/// 이 정사각형이 썸네일이 되어 지도 마커, 장소 줄, 내보내기 이미지에 보인다(원본은 그대로).
///
/// [image]는 원본, [size]는 그 픽셀 크기다. [initial]이 없으면 가운데에서 시작한다.
Future<Rect?> showPhotoPosition(
  BuildContext context, {
  required ImageProvider image,
  required Size size,
  Rect? initial,
}) => showDialog<Rect>(
  context: context,
  useSafeArea: false,
  builder: (context) => Dialog.fullscreen(
    backgroundColor: context.appColors.photoViewer.background,
    child: PhotoPositionView(image: image, size: size, initial: initial),
  ),
);

/// 사진을 끌고 두 손가락으로 늘려 틀에 맞춘다. 틀은 늘 사진으로 가득 차서 빈 곳이 생기지 않는다.
///
/// 상태는 틀 가운데의 사진 위 자리(비율)와 확대 배수(1~[maxZoom])다. 1배는 사진의 짧은 변이 틀에 꼭 맞는 크기다.
/// 화면 크기에 기대지 않는 값이라 화면이 돌아가도 고른 자리가 그대로다.
class PhotoPositionView extends StatefulWidget {
  const PhotoPositionView({
    super.key,
    required this.image,
    required this.size,
    this.initial,
  });

  static const maxZoom = 4.0;

  final ImageProvider image;
  final Size size;
  final Rect? initial;

  @override
  State<PhotoPositionView> createState() => _PhotoPositionViewState();
}

class _PhotoPositionViewState extends State<PhotoPositionView> {
  /// 틀 가운데가 가리키는 사진 위 자리(폭과 높이에 대한 비율).
  late Offset _center;
  late double _zoom;

  /// 끌기를 시작한 때의 값.
  Offset _startCenter = Offset.zero;
  double _startZoom = 1;
  Offset _startFocal = Offset.zero;

  /// 마지막으로 그린 틀(화면 좌표). 끌기 계산에 쓴다.
  Rect _frame = Rect.zero;

  double get _short => math.min(widget.size.width, widget.size.height);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      _center = const Offset(0.5, 0.5);
      _zoom = 1;
    } else {
      _center = initial.center;
      _zoom = (_short / (initial.width * widget.size.width)).clamp(
        1.0,
        PhotoPositionView.maxZoom,
      );
    }
  }

  /// 화면 1px이 사진 몇 px인지의 역수(사진 1px의 화면 크기).
  double _scale(Rect frame) => frame.width / _short * _zoom;

  /// 틀이 사진 밖으로 나가지 않게 [center]를 민다.
  Offset _clamp(Offset center, double scale, Rect frame) {
    final spanX = frame.width / (widget.size.width * scale);
    final spanY = frame.height / (widget.size.height * scale);
    return Offset(
      center.dx.clamp(spanX / 2, 1 - spanX / 2),
      center.dy.clamp(spanY / 2, 1 - spanY / 2),
    );
  }

  Rect _area(Rect frame) {
    final scale = _scale(frame);
    final spanX = frame.width / (widget.size.width * scale);
    final spanY = frame.height / (widget.size.height * scale);
    return Rect.fromCenter(
      center: _clamp(_center, scale, frame),
      width: spanX,
      height: spanY,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startCenter = _center;
    _startZoom = _zoom;
    _startFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final frame = _frame;
    if (frame.isEmpty) return;
    final startScale = frame.width / _short * _startZoom;
    final zoom = (_startZoom * details.scale).clamp(
      1.0,
      PhotoPositionView.maxZoom,
    );
    final scale = frame.width / _short * zoom;
    // 손가락 아래 있던 사진 자리가 손가락을 따라오게 한다.
    final width = widget.size.width;
    final height = widget.size.height;
    final grabbed = Offset(
      _startCenter.dx +
          (_startFocal.dx - frame.center.dx) / (width * startScale),
      _startCenter.dy +
          (_startFocal.dy - frame.center.dy) / (height * startScale),
    );
    final focal = details.localFocalPoint;
    final center = Offset(
      grabbed.dx - (focal.dx - frame.center.dx) / (width * scale),
      grabbed.dy - (focal.dy - frame.center.dy) / (height * scale),
    );
    setState(() {
      _zoom = zoom;
      _center = _clamp(center, scale, frame);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors.photoViewer;
    final textTheme = Theme.of(context).textTheme;
    final insets = MediaQuery.paddingOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            insets.left + AppSpace.sm,
            insets.top + AppSpace.sm,
            insets.right + AppSpace.lg,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                color: colors.foreground,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                l10n.photoPositionTitle,
                style: textTheme.titleMedium?.copyWith(
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side =
                  math.min(constraints.maxWidth, constraints.maxHeight) -
                  AppSpace.xl * 2;
              final frame = Rect.fromCenter(
                center: constraints.biggest.center(Offset.zero),
                width: side,
                height: side,
              );
              _frame = frame;
              final scale = _scale(frame);
              final center = _clamp(_center, scale, frame);
              final imageSize = widget.size * scale;
              final topLeft =
                  frame.center -
                  Offset(
                    center.dx * imageSize.width,
                    center.dy * imageSize.height,
                  );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        left: topLeft.dx,
                        top: topLeft.dy,
                        width: imageSize.width,
                        height: imageSize.height,
                        child: Image(
                          image: widget.image,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FramePainter(
                              frame: frame,
                              mask: colors.background.withValues(alpha: 0.6),
                              border: colors.foreground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            insets.left + AppSpace.lg,
            AppSpace.sm,
            insets.right + AppSpace.lg,
            insets.bottom + AppSpace.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.photoPositionHint,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_area(_frame)),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 틀 밖을 어둡게 덮고 틀에 선을 긋는다.
class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.frame,
    required this.mask,
    required this.border,
  });

  final Rect frame;
  final Color mask;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(frame),
      ),
      Paint()..color = mask,
    );
    canvas.drawRect(
      frame,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.mask != mask ||
      oldDelegate.border != border;
}

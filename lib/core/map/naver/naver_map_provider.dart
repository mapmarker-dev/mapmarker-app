import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../geometry/route_geometry.dart';
import '../../theme/app_tokens.dart';
import '../geo.dart';
import '../map_provider.dart';
import '../marker_icon.dart';
import '../route_arrow.dart';
import '../route_curve.dart';

/// 네이버 지도. 1단계(국내)는 이 지도만 쓴다.
///
/// SDK 초기화는 `main.dart`가 한다. 이 파일 밖의 앱 코드는 `flutter_naver_map`을 쓰지 않는다
/// (0단계 검증 화면 `dev/snapshot_lab/`만 예외).
class NaverMapProvider implements MapProvider {
  const NaverMapProvider();

  @override
  Widget buildMap(
    MapScene scene, {
    ValueChanged<String>? onMarkerTap,
    ValueChanged<String>? onLineTap,
    ValueChanged<MapTap>? onMapTap,
    void Function(String id, double curvature)? onCurveChanged,
  }) => NaverMapView(
    scene: scene,
    onMarkerTap: onMarkerTap,
    onLineTap: onLineTap,
    onMapTap: onMapTap,
    onCurveChanged: onCurveChanged,
  );
}

/// 장소가 없는 여행을 처음 열 때 보여 줄 곳: 한국 전체.
const _korea = NCameraPosition(target: NLatLng(36.3, 127.8), zoom: 5.8);

/// 카메라를 맞출 때 마커와 이름이 지도 가장자리에 붙지 않게 더 띄우는 여백.
const _fitPadding = EdgeInsets.all(AppSpace.xxl + AppSpace.lg);

/// 로고는 가리거나 끄면 안 된다. 왼쪽 아래에 고정하고, [MapScene.padding] 안쪽에서 이만큼 띄운다.
/// 아래에서 시트가 더 올라오면 [MapScene.logoLift]만큼 더 올린다.
const _logoMargin = EdgeInsets.all(AppSpace.md);

const _lineWidth = 5.0;
const _lineOutlineWidth = 1.5;

// 점선·파선의 무늬(dp). 그리는 길이와 빈칸 길이를 번갈아 적는다. 실기기를 보며 맞춘다.

/// 긴 파선(비행기·배). 끝은 네모로 잘라 빈칸이 또렷하게 보이게 한다.
const _dashPattern = [12, 8];

/// 둥근 점선(도보). 아주 짧은 선에 둥근 끝을 붙여 점으로 만든다. 점 지름은 선 두께쯤이다.
const _dotPattern = [1, 11];

class NaverMapView extends StatefulWidget {
  const NaverMapView({
    super.key,
    required this.scene,
    this.onMarkerTap,
    this.onLineTap,
    this.onMapTap,
    this.onCurveChanged,
  });

  final MapScene scene;
  final ValueChanged<String>? onMarkerTap;
  final ValueChanged<String>? onLineTap;
  final ValueChanged<MapTap>? onMapTap;
  final void Function(String id, double curvature)? onCurveChanged;

  @override
  State<NaverMapView> createState() => _NaverMapViewState();
}

/// 곡선 핸들을 잡는 터치 영역의 크기. 핸들 그림보다 커서 손가락으로 잡기 쉽다.
const _handleTouchSize = 48.0;

/// 곡선 핸들의 화면 위치. 카메라가 멈출 때마다 지도에 다시 묻는다.
@immutable
class _HandleLayout {
  const _HandleLayout(this.handle, this.from, this.to);

  final MapCurveHandle handle;

  /// 양 끝 장소의 화면 위치(논리 px, 지도 왼쪽 위 기준).
  final Offset from;
  final Offset to;

  Offset get middle => curveMiddleOnScreen(from, to, handle.curvature);
}

/// 곡선 핸들(SDK 마커에는 끌기가 없다)
///
/// - 모양: 네이버 마커([naverCurveHandleOf]). 지도를 움직이면 SDK가 부드럽게 따라 옮긴다.
/// - 터치: 그 자리에 Flutter 터치 영역을 둔다. 지도 위의 Flutter 위젯이 터치를 먼저 받아서 핸들을 잡은 동안 지도가 같이 움직이지 않는다.
/// - 끌기: 끌기 시작할 때의 양 끝 화면 위치만으로 곡률을 계산한다([curvatureForHandle]).
///   끄는 동안 지도에 좌표를 다시 묻지 않고, 새 곡선과 핸들은 Flutter로 미리 그린다.
/// - 놓으면 `onCurveChanged`로 알리고, 저장한 곡률로 장면이 다시 오면 미리보기를 지운다.
class _NaverMapViewState extends State<NaverMapView> {
  NaverMapController? _controller;

  _HandleLayout? _handleLayout;

  /// 핸들 위치를 묻는 중에 또 물으면 앞의 답은 버린다.
  int _handleVersion = 0;

  /// 올려 둔 네이버 핸들. 끄는 동안 투명하게 둔다.
  NMarker? _handleMarker;

  /// 끄는 중인 곡률. 끄지 않으면 null이다.
  double? _dragCurvature;

  /// 끄기 시작한 때의 핸들 자리. 끄는 동안 터치 영역은 이 자리에 그대로 있다.
  _HandleLayout? _dragLayout;

  /// 끄기 시작할 때 손가락이 닿은 자리(터치 영역 안 좌표).
  Offset _dragGrab = Offset.zero;

  /// 핸들에 손가락이 닿아 있는지. 그동안 지도 제스처(이동·확대·회전)를 끈다.
  bool _holdingHandle = false;

  /// 마지막으로 맞춘 카메라 요청의 key.
  Object? _cameraKey;

  /// 오버레이를 바꾸는 중에 장면이 또 바뀌면 앞의 작업을 버린다.
  int _overlayVersion = 0;

  /// 마커 그림은 만들 때 시간이 걸려서, 같은 그림은 한 번만 만든다.
  final _icons = <MarkerLook, NOverlayImage>{};
  final _arrowIcons = <(Color, Color), NOverlayImage>{};
  final _lineIconImages = <(IconData, Color, Color, Color), NOverlayImage>{};
  final _curveHandleIcons = <(Color, Color), NOverlayImage>{};

  @override
  void didUpdateWidget(NaverMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null) return;
    final old = oldWidget.scene;
    final scene = widget.scene;
    if (!listEquals(old.markers, scene.markers) ||
        !listEquals(old.lines, scene.lines) ||
        !listEquals(old.arrows, scene.arrows) ||
        !listEquals(old.lineIcons, scene.lineIcons) ||
        old.curveHandle != scene.curveHandle) {
      _showOverlays(controller);
    }
    if (old.curveHandle != scene.curveHandle) _refreshHandle();
    _moveCamera(controller);
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _controller = controller;
    _moveCamera(controller, animate: false);
    await _showOverlays(controller);
    await _refreshHandle();
  }

  /// 핸들의 화면 위치를 다시 잰다. 핸들이 없으면 터치 영역을 치운다.
  Future<void> _refreshHandle() async {
    final version = ++_handleVersion;
    final controller = _controller;
    final handle = widget.scene.curveHandle;
    if (controller == null || handle == null) {
      if (_handleLayout != null) setState(() => _handleLayout = null);
      return;
    }
    final from = await controller.latLngToScreenLocation(_nLatLng(handle.from));
    final to = await controller.latLngToScreenLocation(_nLatLng(handle.to));
    if (!mounted || version != _handleVersion) return;
    setState(
      () => _handleLayout = _HandleLayout(
        handle,
        Offset(from.x, from.y),
        Offset(to.x, to.y),
      ),
    );
  }

  /// 카메라가 움직이는 동안은 터치 영역의 자리가 맞지 않아서 치운다. 멈추면 다시 잰다.
  ///
  /// 끄는 중에 사용자 제스처로 지도가 움직였으면(지도 제스처를 끄기 전에 지도가 먼저 받은 경우)
  /// 그 끌기를 버린다. 미리보기는 끌기 시작한 때의 화면 위치로 그려서, 지도가 움직이면 선과 갈라진다.
  ///
  /// 지도 옵션이 바뀌면(예: 핸들에 닿아 제스처를 끌 때) SDK가 여백을 다시 적용하며 `contentPadding` 이유로
  /// 이 함수를 부른다. 그때 터치 영역을 치우면 닿아 있던 손가락의 끌기가 끊겨서, 그 이유는 무시한다
  /// (여백이 정말 바뀌었으면 멈출 때 다시 잰다).
  void _onCameraChange(NCameraUpdateReason reason) {
    if (reason == NCameraUpdateReason.contentPadding) return;
    if (_dragCurvature != null || _holdingHandle) {
      if (reason == NCameraUpdateReason.gesture) _cancelDrag();
      return;
    }
    if (_handleLayout == null) return;
    ++_handleVersion;
    setState(() => _handleLayout = null);
  }

  void _holdHandle() {
    if (_holdingHandle) return;
    setState(() => _holdingHandle = true);
  }

  void _releaseHandle() {
    if (!_holdingHandle) return;
    setState(() => _holdingHandle = false);
  }

  /// 저장하지 않고 끌기를 그만둔다. 핸들은 끌기 전 자리로 돌아간다.
  void _cancelDrag() {
    _releaseHandle();
    _clearDrag();
    _refreshHandle();
  }

  void _onCameraIdle() {
    if (widget.scene.curveHandle != null && _dragCurvature == null) {
      _refreshHandle();
    }
  }

  /// [grab]은 손가락이 닿은 자리의 터치 영역 안 좌표다.
  void _startDrag(Offset grab) {
    final layout = _handleLayout;
    if (layout == null) return;
    _handleMarker?.setAlpha(0);
    setState(() {
      _dragLayout = layout;
      _dragGrab = grab;
      _dragCurvature = layout.handle.curvature;
    });
  }

  /// [local]은 끄기 시작한 자리의 터치 영역 안 좌표다.
  void _drag(Offset local) {
    final layout = _dragLayout;
    final before = _dragCurvature;
    if (layout == null || before == null) return;
    final curvature = curvatureForHandle(
      layout.from,
      layout.to,
      layout.middle + (local - _dragGrab),
    );
    // 직선에 붙거나 떨어질 때 가볍게 떨어 알린다.
    if ((curvature == 0) != (before == 0)) HapticFeedback.selectionClick();
    setState(() => _dragCurvature = curvature);
  }

  void _endDrag() {
    _releaseHandle();
    final layout = _dragLayout;
    final curvature = _dragCurvature;
    if (layout == null || curvature == null) return;
    if (curvature == layout.handle.curvature) {
      _clearDrag();
      return;
    }
    // 저장한 곡률로 장면이 다시 오면(_showOverlays) 미리보기를 지운다.
    widget.onCurveChanged?.call(layout.handle.id, curvature);
  }

  void _clearDrag() {
    _handleMarker?.setAlpha(1);
    if (_dragCurvature == null && _dragLayout == null) return;
    setState(() {
      _dragCurvature = null;
      _dragLayout = null;
    });
  }

  Future<void> _showOverlays(NaverMapController controller) async {
    final version = ++_overlayVersion;
    final scene = widget.scene;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final markers = <NMarker>[];
    for (final marker in scene.markers) {
      final icon = await _iconOf(marker.look);
      if (!mounted || version != _overlayVersion) return;
      markers.add(
        naverMarkerOf(
          marker,
          icon: icon,
          captionColor: textColor,
          // 오버레이는 장면이 바뀔 때만 다시 올린다. 누른 때의 함수를 부르게 widget에서 읽는다.
          onTap: () => widget.onMarkerTap?.call(marker.id),
        ),
      );
    }
    final arrows = <NMarker>[];
    for (final arrow in scene.arrows) {
      final icon = await _arrowIconOf(arrow);
      if (!mounted || version != _overlayVersion) return;
      arrows.add(naverArrowOf(arrow, icon: icon));
    }
    final lineIcons = <NMarker>[];
    for (final lineIcon in scene.lineIcons) {
      final icon = await _lineIconImageOf(lineIcon);
      if (!mounted || version != _overlayVersion) return;
      lineIcons.add(
        naverLineIconOf(
          lineIcon,
          icon: icon,
          onTap: () => widget.onLineTap?.call(lineIcon.id),
        ),
      );
    }
    NMarker? handleMarker;
    if (scene.curveHandle case final handle?) {
      final icon = await _curveHandleIconOf(handle);
      if (!mounted || version != _overlayVersion) return;
      handleMarker = naverCurveHandleOf(handle, icon: icon);
    }
    await controller.clearOverlays();
    if (!mounted || version != _overlayVersion) return;
    _handleMarker = handleMarker;
    await controller.addOverlayAll({
      for (final line in scene.lines)
        ...naverLinesOf(line, onTap: () => widget.onLineTap?.call(line.id)),
      ...arrows,
      ...lineIcons,
      ?handleMarker,
      ...markers,
    });
    if (!mounted || version != _overlayVersion) return;
    // 끌어 놓은 곡률이 저장돼 새 선이 올라왔다. 미리보기를 지운다.
    if (_dragCurvature != null) _clearDrag();
  }

  Future<NOverlayImage> _curveHandleIconOf(MapCurveHandle handle) async =>
      _curveHandleIcons[(
        handle.color,
        handle.outline,
      )] ??= await NOverlayImage.fromWidget(
        widget: CurveHandleIcon(color: handle.color, outline: handle.outline),
        size: CurveHandleIcon.size,
        context: context,
      );

  Future<NOverlayImage> _lineIconImageOf(MapLineIcon lineIcon) async =>
      _lineIconImages[(
        lineIcon.icon,
        lineIcon.background,
        lineIcon.border,
        lineIcon.foreground,
      )] ??= await NOverlayImage.fromWidget(
        widget: LineIconBadge(lineIcon),
        size: LineIconBadge.size,
        context: context,
      );

  Future<NOverlayImage> _iconOf(MarkerLook look) async =>
      _icons[look] ??= await NOverlayImage.fromWidget(
        widget: MarkerIcon(look),
        size: MarkerIcon.size,
        context: context,
      );

  Future<NOverlayImage> _arrowIconOf(MapArrow arrow) async =>
      _arrowIcons[(
        arrow.color,
        arrow.outline,
      )] ??= await NOverlayImage.fromWidget(
        widget: ArrowIcon(color: arrow.color, outline: arrow.outline),
        size: ArrowIcon.size,
        context: context,
      );

  void _moveCamera(NaverMapController controller, {bool animate = true}) {
    final camera = widget.scene.camera;
    if (camera.key == _cameraKey) return;
    _cameraKey = camera.key;
    final bounds = camera.bounds;
    if (bounds == null) return;
    controller.updateCamera(naverFitOf(bounds, animate: animate));
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final touch = _dragLayout ?? _handleLayout;
    final dragCurvature = _dragCurvature;
    final dragLayout = _dragLayout;
    // 자식마다 key를 단다. 끌기를 시작하며 미리보기를 끼워 넣을 때 key가 없으면, Flutter가 터치 영역의
    // 자리를 미리보기로 바꿔 써서 받던 끌기가 끊긴다(실기기에서 끌기가 한 번씩 무시됐다).
    // 지도도 key로 묶어 두어 핸들이 생기고 없어져도 네이티브 지도를 다시 만들지 않는다.
    //
    // 손가락이 지도 어디서 떨어지든 지도 제스처를 다시 켠다. 터치 영역이 먼저 사라져도 꺼진 채 남지 않게 한다.
    return Listener(
      onPointerUp: (_) => _releaseHandle(),
      onPointerCancel: (_) => _releaseHandle(),
      child: Stack(
        children: [
          Positioned.fill(
            key: const ValueKey('map'),
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: _korea,
                contentPadding: scene.padding,
                logoAlign: NLogoAlign.leftBottom,
                logoMargin:
                    _logoMargin + EdgeInsets.only(bottom: scene.logoLift),
                scaleBarEnable: false,
                indoorEnable: false,
                // 기울인 지도에서는 화면 좌표가 원근으로 비틀려서, 핸들이 있는 동안은 기울이지 않는다.
                tiltGesturesEnable: scene.curveHandle == null,
                // 핸들에 손가락이 닿아 있는 동안 지도가 같이 움직이지 않게 한다.
                scrollGesturesEnable: !_holdingHandle,
                zoomGesturesEnable: !_holdingHandle,
                rotationGesturesEnable: !_holdingHandle,
              ),
              onMapReady: _onMapReady,
              onCameraChange: (reason, _) => _onCameraChange(reason),
              onCameraIdle: _onCameraIdle,
              onMapTapped: (_, latLng) =>
                  widget.onMapTap?.call(MapTap(_latLng(latLng))),
              onSymbolTapped: (symbol) => widget.onMapTap?.call(
                MapTap(
                  _latLng(symbol.position),
                  placeName: naverPlaceNameOf(symbol.caption),
                ),
              ),
            ),
          ),
          if (dragLayout != null && dragCurvature != null)
            Positioned.fill(
              key: const ValueKey('curve-preview'),
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CurvePreviewPainter(
                    from: dragLayout.from,
                    to: dragLayout.to,
                    curvature: dragCurvature,
                    color: dragLayout.handle.color,
                    outline: dragLayout.handle.outline,
                  ),
                ),
              ),
            ),
          if (dragLayout != null && dragCurvature != null)
            _PreviewHandle(
              key: const ValueKey('curve-preview-handle'),
              layout: dragLayout,
              curvature: dragCurvature,
            ),
          if (touch != null)
            Positioned(
              key: const ValueKey('curve-handle-touch'),
              left: touch.middle.dx - _handleTouchSize / 2,
              top: touch.middle.dy - _handleTouchSize / 2,
              width: _handleTouchSize,
              height: _handleTouchSize,
              // 손가락이 떨어지면 끌기 콜백이 오지 않아도 지도 제스처를 다시 켠다.
              child: Listener(
                onPointerUp: (_) => _releaseHandle(),
                onPointerCancel: (_) => _cancelDrag(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // 끌기는 손가락이 조금 움직여야 시작된다. 닿는 순간 지도 제스처부터 끈다.
                  onPanDown: (_) => _holdHandle(),
                  onPanStart: (details) => _startDrag(details.localPosition),
                  onPanUpdate: (details) => _drag(details.localPosition),
                  onPanEnd: (_) => _endDrag(),
                  onPanCancel: _cancelDrag,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 끄는 동안 그리는 새 곡선. 손을 떼고 저장하면 네이버 선으로 바뀐다.
/// 무늬(점선·파선) 없이 실선으로 그린다. 원래 선은 아래에 그대로 남아 바뀌기 전 모양이 보인다.
class _CurvePreviewPainter extends CustomPainter {
  _CurvePreviewPainter({
    required this.from,
    required this.to,
    required this.curvature,
    required this.color,
    required this.outline,
  });

  final Offset from;
  final Offset to;
  final double curvature;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final control = quadraticControlPoint(from, to, curvature);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(path, stroke(outline, _lineWidth + _lineOutlineWidth * 2))
      ..drawPath(path, stroke(color, _lineWidth));
  }

  @override
  bool shouldRepaint(_CurvePreviewPainter old) =>
      old.from != from ||
      old.to != to ||
      old.curvature != curvature ||
      old.color != color ||
      old.outline != outline;
}

/// 끄는 동안 손가락을 따라가는 핸들. 네이버 핸들과 같은 그림을 곡선 방향으로 돌린다.
class _PreviewHandle extends StatelessWidget {
  const _PreviewHandle({
    super.key,
    required this.layout,
    required this.curvature,
  });

  final _HandleLayout layout;
  final double curvature;

  @override
  Widget build(BuildContext context) {
    final middle = curveMiddleOnScreen(layout.from, layout.to, curvature);
    final bearing = curveBearingOnScreen(layout.from, layout.to, curvature);
    final size = CurveHandleIcon.size;
    return Positioned(
      left: middle.dx - size.width / 2,
      top: middle.dy - size.height / 2,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: bearing * math.pi / 180,
          child: CurveHandleIcon(
            color: layout.handle.color,
            outline: layout.handle.outline,
          ),
        ),
      ),
    );
  }
}

// 아래는 SDK 오버레이와 카메라 요청을 만든다. SDK는 이것을 메시지로 바꿔 네이티브 지도에 보낸다.

/// 선을 네이버 오버레이로. 그릴 길이가 없으면 비어 있다.
///
/// - 실선: 테두리가 있는 경로선([naverPathOf]) 하나.
/// - 점선·파선: 경로선에는 점선이 없어서 무늬가 있는 폴리라인([naverPatternLinesOf]) 두 개.
@visibleForTesting
List<NAddableOverlay> naverLinesOf(MapLine line, {VoidCallback? onTap}) =>
    switch (line.style) {
      MapLineStyle.solid => [?naverPathOf(line, onTap: onTap)],
      MapLineStyle.dashed ||
      MapLineStyle.dotted => naverPatternLinesOf(line, onTap: onTap),
    };

/// 점선·파선.
@visibleForTesting
List<NPolylineOverlay> naverPatternLinesOf(
  MapLine line, {
  VoidCallback? onTap,
}) {
  if (line.points.toSet().length < 2) return const [];
  final dotted = line.style == MapLineStyle.dotted;
  // SDK는 무늬도 List로만 메시지로 바꾼다.
  final pattern = [...dotted ? _dotPattern : _dashPattern];
  final cap = dotted ? NLineCap.round : NLineCap.butt;
  NPolylineOverlay polyline(String id, Color color, double width, int z) {
    final overlay = NPolylineOverlay(
      id: id,
      coords: [for (final point in line.points) _nLatLng(point)],
      color: color,
      width: width,
      lineCap: cap,
      lineJoin: NLineJoin.round,
      pattern: pattern,
    )..setGlobalZIndex(z);
    if (onTap != null) overlay.setOnTapListener((_) => onTap());
    return overlay;
  }

  return [
    polyline(
      'halo:${line.id}',
      line.outline,
      _lineWidth + _lineOutlineWidth * 2,
      _lineGlobalZIndex - 1,
    ),
    polyline(line.id, line.color, _lineWidth, _lineGlobalZIndex),
  ];
}

/// 선 높이. 네이버 경로선의 기본 높이와 같아서, 점선과 실선이 같은 높이에 그려진다.
const _lineGlobalZIndex = -100000;

/// 선을 네이버 경로선으로. 그릴 길이가 없으면 null이다.
@visibleForTesting
NPathOverlay? naverPathOf(MapLine line, {VoidCallback? onTap}) {
  // SDK는 서로 다른 점이 두 개 이상이어야 한다.
  if (line.points.toSet().length < 2) return null;
  final path = NPathOverlay(
    id: line.id,
    // SDK는 좌표를 List로만 메시지로 바꾼다. map()으로 만든 Iterable을 그대로 넘기면 실패한다.
    coords: [for (final point in line.points) _nLatLng(point)],
    width: _lineWidth,
    color: line.color,
    outlineWidth: _lineOutlineWidth,
    outlineColor: line.outline,
  );
  if (onTap != null) path.setOnTapListener((_) => onTap());
  return path;
}

@visibleForTesting
NMarker naverMarkerOf(
  MapMarker marker, {
  required NOverlayImage? icon,
  required Color captionColor,
  VoidCallback? onTap,
}) {
  final nMarker = NMarker(
    id: marker.id,
    position: _nLatLng(marker.position),
    icon: icon,
    size: MarkerIcon.size,
    anchor: const NPoint(0.5, 0.5),
    caption: NOverlayCaption(
      text: marker.caption,
      color: captionColor,
      haloColor: marker.look.halo,
    ),
    isHideCollidedCaptions: true,
  );
  if (onTap != null) nMarker.setOnTapListener((_) => onTap());
  return nMarker;
}

/// 심볼 이름. 여러 줄로 쓰인 이름(예: 공항의 이름과 터미널)은 한 줄로 잇는다.
@visibleForTesting
String? naverPlaceNameOf(String caption) {
  final name = caption.replaceAll(RegExp(r'\s+'), ' ').trim();
  return name.isEmpty ? null : name;
}

/// 화살표는 선(-100000)보다 위, 장소 마커(200000)보다 아래에 그린다.
/// 네이버의 화살촉 경로선(`NArrowheadPathOverlay`)과 같은 높이다.
const _arrowGlobalZIndex = 100000;

/// 화살표를 지도와 함께 도는 평평한 마커로. 아이콘이 위(북쪽)를 가리키므로 방향만큼 돌린다.
/// 마커 ID가 장소 마커와 겹치지 않게 앞에 `arrow:`를 붙인다.
@visibleForTesting
NMarker naverArrowOf(MapArrow arrow, {required NOverlayImage? icon}) =>
    NMarker(
        id: 'arrow:${arrow.id}',
        position: _nLatLng(arrow.position),
        icon: icon,
        size: ArrowIcon.size,
        anchor: const NPoint(0.5, 0.5),
        angle: arrow.bearing,
        isFlat: true,
      )
      ..setGlobalZIndex(_arrowGlobalZIndex)
      ..setMinZoom(arrow.minZoom);

/// 곡선 핸들은 선 아이콘(150000)보다 위, 장소 마커(200000)보다 아래에 그린다.
const _curveHandleGlobalZIndex = 170000;

/// 곡선 핸들을 곡선 가운데에 놓는 평평한 마커로. 그림 안의 화살표가 곡선 방향을 가리키게 돌린다.
///
/// 터치는 지도 위 Flutter 영역이 받아서 탭 리스너를 달지 않는다(달면 지도 탭을 가로챈다).
/// 마커 ID가 다른 마커와 겹치지 않게 앞에 `curve-handle:`을 붙인다.
@visibleForTesting
NMarker naverCurveHandleOf(
  MapCurveHandle handle, {
  required NOverlayImage? icon,
}) {
  final middle = routeArrow(
    handle.from,
    handle.to,
    curvature: handle.curvature,
  );
  return NMarker(
    id: 'curve-handle:${handle.id}',
    position: _nLatLng(middle?.position ?? handle.from),
    icon: icon,
    size: CurveHandleIcon.size,
    anchor: const NPoint(0.5, 0.5),
    angle: middle?.bearing ?? 0,
    isFlat: true,
  )..setGlobalZIndex(_curveHandleGlobalZIndex);
}

/// 선 아이콘은 화살표(100000)보다 위, 장소 마커(200000)보다 아래에 그린다.
const _lineIconGlobalZIndex = 150000;

/// 선 아이콘을 세운 마커로. 지도를 돌려도 아이콘이 서 있다.
/// 마커 ID가 장소 마커·화살표와 겹치지 않게 앞에 `line-icon:`을 붙인다.
/// 누르면 그 선을 누른 것과 같다.
@visibleForTesting
NMarker naverLineIconOf(
  MapLineIcon lineIcon, {
  required NOverlayImage? icon,
  VoidCallback? onTap,
}) {
  final marker =
      NMarker(
          id: 'line-icon:${lineIcon.id}',
          position: _nLatLng(lineIcon.position),
          icon: icon,
          size: LineIconBadge.size,
          anchor: const NPoint(0.5, 0.5),
        )
        ..setGlobalZIndex(_lineIconGlobalZIndex)
        ..setMinZoom(lineIcon.minZoom);
  if (onTap != null) marker.setOnTapListener((_) => onTap());
  return marker;
}

/// [bounds]가 보이게 카메라를 옮기는 요청. 처음 열 때는 애니메이션 없이 옮긴다.
@visibleForTesting
NCameraUpdate naverFitOf(LatLngBounds bounds, {required bool animate}) {
  final update = NCameraUpdate.fitBounds(
    NLatLngBounds(
      southWest: _nLatLng(bounds.southWest),
      northEast: _nLatLng(bounds.northEast),
    ),
    padding: _fitPadding,
  );
  if (!animate) {
    update.setAnimation(
      animation: NCameraAnimation.none,
      duration: Duration.zero,
    );
  }
  return update;
}

NLatLng _nLatLng(LatLng p) => NLatLng(p.latitude, p.longitude);

LatLng _latLng(NLatLng p) => LatLng(p.latitude, p.longitude);

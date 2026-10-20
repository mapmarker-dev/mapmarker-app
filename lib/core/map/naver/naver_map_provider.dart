import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../theme/app_tokens.dart';
import '../geo.dart';
import '../map_provider.dart';
import '../marker_icon.dart';

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
  }) => NaverMapView(
    scene: scene,
    onMarkerTap: onMarkerTap,
    onLineTap: onLineTap,
    onMapTap: onMapTap,
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

class NaverMapView extends StatefulWidget {
  const NaverMapView({
    super.key,
    required this.scene,
    this.onMarkerTap,
    this.onLineTap,
    this.onMapTap,
  });

  final MapScene scene;
  final ValueChanged<String>? onMarkerTap;
  final ValueChanged<String>? onLineTap;
  final ValueChanged<MapTap>? onMapTap;

  @override
  State<NaverMapView> createState() => _NaverMapViewState();
}

class _NaverMapViewState extends State<NaverMapView> {
  NaverMapController? _controller;

  /// 마지막으로 맞춘 카메라 요청의 key.
  Object? _cameraKey;

  /// 오버레이를 바꾸는 중에 장면이 또 바뀌면 앞의 작업을 버린다.
  int _overlayVersion = 0;

  /// 마커 그림은 만들 때 시간이 걸려서, 같은 그림은 한 번만 만든다.
  final _icons = <MarkerLook, NOverlayImage>{};
  final _arrowIcons = <(Color, Color), NOverlayImage>{};

  @override
  void didUpdateWidget(NaverMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null) return;
    final old = oldWidget.scene;
    final scene = widget.scene;
    if (!listEquals(old.markers, scene.markers) ||
        !listEquals(old.lines, scene.lines) ||
        !listEquals(old.arrows, scene.arrows)) {
      _showOverlays(controller);
    }
    _moveCamera(controller);
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _controller = controller;
    _moveCamera(controller, animate: false);
    await _showOverlays(controller);
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
    await controller.clearOverlays();
    if (!mounted || version != _overlayVersion) return;
    await controller.addOverlayAll({
      ...scene.lines
          .map(
            (line) =>
                naverPathOf(line, onTap: () => widget.onLineTap?.call(line.id)),
          )
          .nonNulls,
      ...arrows,
      ...markers,
    });
  }

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
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: _korea,
        contentPadding: scene.padding,
        logoAlign: NLogoAlign.leftBottom,
        logoMargin: _logoMargin + EdgeInsets.only(bottom: scene.logoLift),
        scaleBarEnable: false,
        indoorEnable: false,
      ),
      onMapReady: _onMapReady,
      onMapTapped: (_, latLng) =>
          widget.onMapTap?.call(MapTap(_latLng(latLng))),
      onSymbolTapped: (symbol) => widget.onMapTap?.call(
        MapTap(
          _latLng(symbol.position),
          placeName: naverPlaceNameOf(symbol.caption),
        ),
      ),
    );
  }
}

// 아래는 SDK 오버레이와 카메라 요청을 만든다. SDK는 이것을 메시지로 바꿔 네이티브 지도에 보낸다.

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

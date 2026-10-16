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
  Widget buildMap(MapScene scene) => NaverMapView(scene: scene);
}

/// 장소가 없는 여행을 처음 열 때 보여 줄 곳: 한국 전체.
const _korea = NCameraPosition(target: NLatLng(36.3, 127.8), zoom: 5.8);

/// 카메라를 맞출 때 마커와 이름이 지도 가장자리에 붙지 않게 더 띄우는 여백.
const _fitPadding = EdgeInsets.all(AppSpace.xxl + AppSpace.lg);

/// 로고는 가리거나 끄면 안 된다. 왼쪽 아래에 고정하고, [MapScene.padding] 안쪽에서 이만큼 띄운다.
const _logoMargin = EdgeInsets.all(AppSpace.md);

const _lineWidth = 5.0;
const _lineOutlineWidth = 1.5;

class NaverMapView extends StatefulWidget {
  const NaverMapView({super.key, required this.scene});

  final MapScene scene;

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

  @override
  void didUpdateWidget(NaverMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null) return;
    final old = oldWidget.scene;
    final scene = widget.scene;
    if (!listEquals(old.markers, scene.markers) ||
        !listEquals(old.lines, scene.lines)) {
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
      markers.add(naverMarkerOf(marker, icon: icon, captionColor: textColor));
    }
    await controller.clearOverlays();
    if (!mounted || version != _overlayVersion) return;
    await controller.addOverlayAll({
      ...scene.lines.map(naverPathOf).nonNulls,
      ...markers,
    });
  }

  Future<NOverlayImage> _iconOf(MarkerLook look) async =>
      _icons[look] ??= await NOverlayImage.fromWidget(
        widget: MarkerIcon(look),
        size: MarkerIcon.size,
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
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: _korea,
        contentPadding: widget.scene.padding,
        logoAlign: NLogoAlign.leftBottom,
        logoMargin: _logoMargin,
        scaleBarEnable: false,
        indoorEnable: false,
      ),
      onMapReady: _onMapReady,
    );
  }
}

// 아래는 SDK 오버레이와 카메라 요청을 만든다. SDK는 이것을 메시지로 바꿔 네이티브 지도에 보낸다.

/// 선을 네이버 경로선으로. 그릴 길이가 없으면 null이다.
@visibleForTesting
NPathOverlay? naverPathOf(MapLine line) {
  // SDK는 서로 다른 점이 두 개 이상이어야 한다.
  if (line.points.toSet().length < 2) return null;
  return NPathOverlay(
    id: line.id,
    // SDK는 좌표를 List로만 메시지로 바꾼다. map()으로 만든 Iterable을 그대로 넘기면 실패한다.
    coords: [for (final point in line.points) _nLatLng(point)],
    width: _lineWidth,
    color: line.color,
    outlineWidth: _lineOutlineWidth,
    outlineColor: line.outline,
  );
}

@visibleForTesting
NMarker naverMarkerOf(
  MapMarker marker, {
  required NOverlayImage? icon,
  required Color captionColor,
}) => NMarker(
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

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../theme/app_tokens.dart';
import '../geo.dart';
import '../map_capture.dart';

/// 로고 자리. 왼쪽 아래 구석에서 이만큼 띄운다.
const _logoMargin = EdgeInsets.all(AppSpace.md);

/// 로고와 둘레를 넉넉히 감싸는 영역(논리 px, 왼쪽 아래 구석 기준). 0단계에서 실기기로 잰 값이다.
const _logoReserve = Size(112, 48);

/// 맞춘 뒤 찍기까지 기다리는 때. 첫 장은 빨리 보여 주고, 늦게 받은 지도 조각이 있을 수 있어 한 번 더 찍는다.
const _captureDelays = [
  Duration(milliseconds: 500),
  Duration(milliseconds: 1600),
];

/// 지도를 이 시간 안에 다 받지 못하면 실패로 본다.
const _loadTimeout = Duration(seconds: 12);

/// 내보내기 이미지의 바탕을 찍는 네이버 지도. 오버레이와 제스처가 없다.
class NaverCaptureMap extends StatefulWidget {
  const NaverCaptureMap({
    super.key,
    required this.frame,
    required this.onCaptured,
    required this.onFailed,
  });

  final MapFrame frame;
  final ValueChanged<MapCapture> onCaptured;
  final VoidCallback onFailed;

  @override
  State<NaverCaptureMap> createState() => _NaverCaptureMapState();
}

class _NaverCaptureMapState extends State<NaverCaptureMap> {
  NaverMapController? _controller;
  bool _loaded = false;
  bool _failed = false;

  /// 맞출 때마다 올린다. 찍는 중에 범위가 바뀌면 앞의 결과는 버린다.
  int _version = 0;
  final _timers = <Timer>[];
  Timer? _loadTimer;

  @override
  void didUpdateWidget(NaverCaptureMap old) {
    super.didUpdateWidget(old);
    if (old.frame != widget.frame) _fit();
  }

  @override
  void dispose() {
    _cancelTimers();
    _loadTimer?.cancel();
    super.dispose();
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _onMapReady(NaverMapController controller) {
    _controller = controller;
    _loadTimer = Timer(_loadTimeout, () {
      if (!_loaded && mounted) _fail();
    });
    _fit();
  }

  void _onMapLoaded() {
    _loaded = true;
    _loadTimer?.cancel();
    _scheduleCaptures(_version);
  }

  Future<void> _fit() async {
    final controller = _controller;
    if (controller == null) return;
    final version = ++_version;
    _cancelTimers();
    final frame = widget.frame;
    final update = switch (frame) {
      MapFrame(:final bounds?) => NCameraUpdate.fitBounds(
        NLatLngBounds(
          southWest: _nLatLng(bounds.southWest),
          northEast: _nLatLng(bounds.northEast),
        ),
        padding: frame.padding,
      ),
      MapFrame(:final center, :final zoom) => NCameraUpdate.scrollAndZoomTo(
        target: _nLatLng(center!),
        zoom: zoom,
      ),
    }..setAnimation(animation: NCameraAnimation.none, duration: Duration.zero);
    await controller.updateCamera(update);
    if (!mounted || version != _version) return;
    if (_loaded) _scheduleCaptures(version);
  }

  void _scheduleCaptures(int version) {
    _cancelTimers();
    for (final delay in _captureDelays) {
      _timers.add(Timer(delay, () => _capture(version)));
    }
  }

  Future<void> _capture(int version) async {
    final controller = _controller;
    final size = context.size;
    if (controller == null || size == null || _failed) return;
    final frame = widget.frame;
    try {
      final bounds = await controller.getContentBounds();
      final sw = await controller.latLngToScreenLocation(bounds.southWest);
      final ne = await controller.latLngToScreenLocation(bounds.northEast);
      final camera = await controller.getCameraPosition();
      final file = await controller.takeSnapshot(compressQuality: 100);
      final bytes = await file.readAsBytes();
      file.delete().ignore();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      if (!mounted || version != _version) {
        image.dispose();
        return;
      }
      widget.onCaptured(
        MapCapture(
          image: image,
          frame: frame,
          projection: MapProjection.fromPairs(
            (_latLng(bounds.southWest), Offset(sw.x, sw.y)),
            (_latLng(bounds.northEast), Offset(ne.x, ne.y)),
          ),
          zoom: camera.zoom,
          logo: Rect.fromLTWH(
            0,
            size.height - _logoReserve.height,
            _logoReserve.width,
            _logoReserve.height,
          ),
        ),
      );
    } on Object catch (error) {
      debugPrint('지도를 찍지 못했습니다: $error');
      if (mounted && version == _version) _fail();
    }
  }

  void _fail() {
    if (_failed) return;
    _failed = true;
    _cancelTimers();
    widget.onFailed();
  }

  @override
  Widget build(BuildContext context) => NaverMap(
    options: const NaverMapViewOptions(
      initialCameraPosition: NCameraPosition(
        target: NLatLng(36.3, 127.8),
        zoom: 5.8,
      ),
      logoAlign: NLogoAlign.leftBottom,
      logoMargin: _logoMargin,
      scaleBarEnable: false,
      indoorEnable: false,
      scrollGesturesEnable: false,
      zoomGesturesEnable: false,
      rotationGesturesEnable: false,
      tiltGesturesEnable: false,
      stopGesturesEnable: false,
    ),
    onMapReady: _onMapReady,
    onMapLoaded: _onMapLoaded,
  );
}

NLatLng _nLatLng(LatLng p) => NLatLng(p.latitude, p.longitude);

LatLng _latLng(NLatLng p) => LatLng(p.latitude, p.longitude);

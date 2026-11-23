import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'geo.dart';
import 'route_arrow.dart';

/// 줌 0에서 세계 지도 한 변의 길이(논리 px). 줌이 1 오를 때마다 두 배가 된다.
const _worldSizeAtZoom0 = 256.0;

/// 찍을 지도의 범위. 장소들에 맞추거나([MapFrame.fit]), 한 곳을 가운데에 두고 정한 줌으로 본다([MapFrame.at]).
@immutable
class MapFrame {
  /// [bounds]를 지도 안쪽 [padding] 안에 맞춘다.
  const MapFrame.fit({required LatLngBounds this.bounds, required this.padding})
    : center = null,
      zoom = null;

  /// [center]를 지도 가운데에 두고 [zoom]으로 본다. 사용자가 미리보기를 끌고 늘려 고른 곳이다.
  const MapFrame.at({required LatLng this.center, required double this.zoom})
    : bounds = null,
      padding = EdgeInsets.zero;

  final LatLngBounds? bounds;

  /// 지도 가장자리에서 띄울 여백(논리 px). 이미지 위에 덮을 것(제목 카드, 로고)과 마커가 솟는 높이만큼이다.
  final EdgeInsets padding;

  final LatLng? center;
  final double? zoom;

  @override
  bool operator ==(Object other) =>
      other is MapFrame &&
      other.bounds == bounds &&
      other.padding == padding &&
      other.center == center &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(bounds, padding, center, zoom);

  @override
  String toString() => bounds != null
      ? 'MapFrame.fit($bounds, $padding)'
      : 'MapFrame.at($center, $zoom)';
}

/// 오버레이 없이 찍은 지도 한 장.
@immutable
class MapCapture {
  const MapCapture({
    required this.image,
    required this.frame,
    required this.projection,
    required this.zoom,
    required this.logo,
  });

  /// 지도 그림. 크기는 지도 위젯의 논리 크기 × 기기 픽셀 비율이다.
  final ui.Image image;

  /// 이 그림을 찍을 때 맞춘 범위.
  final MapFrame frame;

  /// 위도·경도 ↔ 지도 위젯 안의 위치(논리 px, 왼쪽 위 기준).
  final MapProjection projection;

  /// 찍을 때의 줌. 미리보기를 늘린 만큼 줌을 바꿀 때 쓴다(두 배 늘리면 줌 +1).
  final double zoom;

  /// 지도 로고가 있는 곳(논리 px). 로고는 가리면 안 되어서, 그 위에 무엇을 그렸으면 이 자리를 지도 그림으로 다시 덮는다.
  final Rect logo;
}

/// 돌리거나 기울이지 않은 지도의 위도·경도 ↔ 화면 위치. 웹 메르카토르 좌표에서 가로·세로로 늘이고 옮긴 것이다.
@immutable
class MapProjection {
  /// 화면 위치를 아는 두 점(가로와 세로가 모두 달라야 한다)으로 만든다. 지도에 매번 묻지 않으려고 쓴다.
  /// [a]와 [b]는 위도·경도와 그 화면 위치의 쌍이다.
  factory MapProjection.fromPairs((LatLng, Offset) a, (LatLng, Offset) b) {
    final ma = mercatorOf(a.$1);
    final mb = mercatorOf(b.$1);
    final dx = mb.dx - ma.dx;
    final dy = mb.dy - ma.dy;
    if (dx == 0 || dy == 0) {
      throw ArgumentError('두 점의 가로와 세로가 모두 달라야 한다: $a, $b');
    }
    final scaleX = (b.$2.dx - a.$2.dx) / dx;
    final scaleY = (b.$2.dy - a.$2.dy) / dy;
    return MapProjection._(
      scaleX,
      scaleY,
      a.$2.dx - ma.dx * scaleX,
      a.$2.dy - ma.dy * scaleY,
    );
  }

  /// [size] 지도의 가운데에 [center]가 오고 줌이 [zoom]인 것.
  factory MapProjection.centered(LatLng center, double zoom, Size size) {
    final world = _worldSizeAtZoom0 * math.pow(2, zoom);
    final m = mercatorOf(center);
    return MapProjection._(
      world,
      world,
      size.width / 2 - m.dx * world,
      size.height / 2 - m.dy * world,
    );
  }

  const MapProjection._(this._scaleX, this._scaleY, this._shiftX, this._shiftY);

  final double _scaleX;
  final double _scaleY;
  final double _shiftX;
  final double _shiftY;

  Offset toScreen(LatLng position) {
    final m = mercatorOf(position);
    return Offset(m.dx * _scaleX + _shiftX, m.dy * _scaleY + _shiftY);
  }

  /// [toScreen]의 반대.
  LatLng toLatLng(Offset point) => latLngOfMercator(
    Offset((point.dx - _shiftX) / _scaleX, (point.dy - _shiftY) / _scaleY),
  );
}

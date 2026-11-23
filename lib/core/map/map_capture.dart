import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'geo.dart';
import 'route_arrow.dart';

/// 찍을 지도의 범위. [bounds]를 지도 안쪽 [padding] 안에 맞춘다.
@immutable
class MapFrame {
  const MapFrame({required this.bounds, required this.padding});

  final LatLngBounds bounds;

  /// 지도 가장자리에서 띄울 여백(논리 px). 이미지 위에 덮을 것(제목 카드, 로고)과 마커가 솟는 높이만큼이다.
  final EdgeInsets padding;

  @override
  bool operator ==(Object other) =>
      other is MapFrame && other.bounds == bounds && other.padding == padding;

  @override
  int get hashCode => Object.hash(bounds, padding);

  @override
  String toString() => 'MapFrame($bounds, $padding)';
}

/// 오버레이 없이 찍은 지도 한 장.
@immutable
class MapCapture {
  const MapCapture({
    required this.image,
    required this.frame,
    required this.projection,
    required this.logo,
  });

  /// 지도 그림. 크기는 지도 위젯의 논리 크기 × 기기 픽셀 비율이다.
  final ui.Image image;

  /// 이 그림을 찍을 때 맞춘 범위.
  final MapFrame frame;

  /// 위도·경도 → 지도 위젯 안의 위치(논리 px, 왼쪽 위 기준).
  final MapProjection projection;

  /// 지도 로고가 있는 곳(논리 px). 로고는 가리면 안 되어서, 그 위에 무엇을 그렸으면 이 자리를 지도 그림으로 다시 덮는다.
  final Rect logo;
}

/// 돌리거나 기울이지 않은 지도의 위도·경도 → 화면 위치. 웹 메르카토르 좌표에서 가로·세로로 늘이고 옮긴 것이다.
///
/// 지도에 매번 묻지 않으려고, 화면 위치를 아는 두 점(가로와 세로가 모두 달라야 한다)으로 만든다.
@immutable
class MapProjection {
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

  const MapProjection._(this._scaleX, this._scaleY, this._shiftX, this._shiftY);

  final double _scaleX;
  final double _scaleY;
  final double _shiftX;
  final double _shiftY;

  Offset toScreen(LatLng position) {
    final m = mercatorOf(position);
    return Offset(m.dx * _scaleX + _shiftX, m.dy * _scaleY + _shiftY);
  }
}

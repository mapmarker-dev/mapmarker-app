import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 위도·경도. 지도 종류와 관계없이 앱 안에서 쓰는 좌표다.
@immutable
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

/// 위도·경도 범위. 날짜변경선을 넘는 범위는 아직 다루지 않는다 (2단계).
@immutable
class LatLngBounds {
  const LatLngBounds({required this.southWest, required this.northEast});

  /// [points]를 모두 담는 가장 작은 범위. [points]가 비어 있으면 안 된다.
  factory LatLngBounds.around(Iterable<LatLng> points) {
    if (points.isEmpty) throw ArgumentError.value(points, 'points', '비어 있음');
    var south = double.infinity;
    var west = double.infinity;
    var north = double.negativeInfinity;
    var east = double.negativeInfinity;
    for (final p in points) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    return LatLngBounds(
      southWest: LatLng(south, west),
      northEast: LatLng(north, east),
    );
  }

  final LatLng southWest;
  final LatLng northEast;

  LatLng get center => LatLng(
    (southWest.latitude + northEast.latitude) / 2,
    (southWest.longitude + northEast.longitude) / 2,
  );

  /// 위도·경도 폭이 [span]도보다 좁으면 가운데를 그대로 두고 [span]까지 넓힌다.
  LatLngBounds widenedTo(double span) {
    (double, double) widen(double low, double high) {
      if (high - low >= span) return (low, high);
      final mid = (low + high) / 2;
      return (mid - span / 2, mid + span / 2);
    }

    final (south, north) = widen(southWest.latitude, northEast.latitude);
    final (west, east) = widen(southWest.longitude, northEast.longitude);
    return LatLngBounds(
      southWest: LatLng(south, west),
      northEast: LatLng(north, east),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LatLngBounds &&
      other.southWest == southWest &&
      other.northEast == northEast;

  @override
  int get hashCode => Object.hash(southWest, northEast);

  @override
  String toString() => 'LatLngBounds($southWest, $northEast)';
}

/// 카메라를 맞출 범위의 최소 폭(도). 위도 0.005도는 약 550m다.
///
/// 장소가 하나이거나 아주 가까이 모여 있으면 지도가 최대로 확대되지 않게 이만큼 넓힌다.
const minCameraSpan = 0.005;

/// [points]가 모두 보이게 카메라를 맞출 범위. 장소가 없으면 null이고, 이때 카메라는 움직이지 않는다.
LatLngBounds? cameraBoundsFor(Iterable<LatLng> points) => points.isEmpty
    ? null
    : LatLngBounds.around(points).widenedTo(minCameraSpan);

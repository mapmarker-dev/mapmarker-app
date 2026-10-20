import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../geometry/route_geometry.dart';
import 'geo.dart';

/// 구간 가운데에 놓는 진행 방향 화살표.
///
/// 화살표는 저장하지 않는다. 구간이 가리키는 방향(출발 장소 → 도착 장소)으로 그린다.
@immutable
class RouteArrow {
  const RouteArrow({
    required this.position,
    required this.bearing,
    required this.minZoom,
  });

  final LatLng position;

  /// 화살표가 가리키는 방향. 북쪽이 0도이고 시계 방향으로 잰다.
  final double bearing;

  /// 이 줌보다 멀리서 보면 숨긴다. 선이 화면에서 짧아지면 화살표가 마커와 겹치기 때문이다.
  final double minZoom;
}

/// 화살표가 보이려면 선이 화면에서 이만큼(논리 px) 길어야 한다.
///
/// 양 끝 마커 반지름(14 + 14)과 화살표(18), 그 사이 여백을 더한 길이다.
const arrowMinLineLength = 72.0;

/// 줌 0에서 세계 지도 한 변의 길이(논리 px). 줌이 1 오를 때마다 두 배가 된다.
const _worldSizeAtZoom0 = 256.0;

const _maxZoom = 21.0;

/// [from]에서 [to]로 가는 구간의 화살표. 두 점이 같으면 방향이 없어서 null이다.
///
/// 화면에 그려지는 선과 맞추려고 메르카토르 좌표에서 계산한다. 위도·경도로 계산하면
/// 위도가 높을수록 방향이 틀어진다.
/// [curvature]는 곡선 구간의 곡률 k로, 곡선 가운데(t = 0.5)에 곡선 방향으로 놓는다.
/// 지금은 선을 직선으로만 그려서 0만 넘긴다.
RouteArrow? routeArrow(LatLng from, LatLng to, {double curvature = 0}) {
  final a = mercatorOf(from);
  final b = mercatorOf(to);
  final length = (b - a).distance;
  if (length == 0) return null;
  final control = quadraticControlPoint(a, b, curvature);
  final middle = quadraticPoint(a, control, b, 0.5);
  final tangent = quadraticTangent(a, control, b, 0.5);
  // 화면 좌표는 아래로 갈수록 y가 커지므로, 북쪽(위)은 -y 방향이다.
  final bearing = math.atan2(tangent.dx, -tangent.dy) * 180 / math.pi;
  return RouteArrow(
    position: latLngOfMercator(middle),
    bearing: (bearing + 360) % 360,
    minZoom: _zoomForLength(length),
  );
}

/// 메르카토르 길이 [length](세계 지도 한 변 = 1)가 화면에서 [arrowMinLineLength]가 되는 줌.
double _zoomForLength(double length) {
  final zoom =
      math.log(arrowMinLineLength / (length * _worldSizeAtZoom0)) / math.ln2;
  return zoom.clamp(0, _maxZoom);
}

/// 웹 메르카토르 좌표. 세계 지도를 한 변이 1인 정사각형으로 펴고, 왼쪽 위가 (0, 0)이다.
Offset mercatorOf(LatLng p) {
  final lat = p.latitude * math.pi / 180;
  return Offset(
    (p.longitude + 180) / 360,
    (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2,
  );
}

LatLng latLngOfMercator(Offset p) {
  final n = math.pi * (1 - 2 * p.dy);
  final lat = math.atan((math.exp(n) - math.exp(-n)) / 2);
  return LatLng(lat * 180 / math.pi, p.dx * 360 - 180);
}

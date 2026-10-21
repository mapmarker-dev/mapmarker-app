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

/// 구간의 1/4 지점(출발 쪽)에 놓는 선 아이콘(이동 수단)의 자리.
@immutable
class RouteLineIconPlace {
  const RouteLineIconPlace({required this.position, required this.minZoom});

  final LatLng position;

  /// 이 줌보다 멀리서 보면 숨긴다. 선이 화면에서 짧아지면 아이콘이 마커·화살표와 겹치기 때문이다.
  final double minZoom;
}

/// 선 아이콘이 보이려면 선이 화면에서 이만큼(논리 px) 길어야 한다.
///
/// 아이콘은 1/4 지점이라 출발 마커와 화살표에서 각각 선 길이의 1/4만큼 떨어진다.
/// 화살표([arrowMinLineLength])에 되도록 맞춰 나타나게 여백 없이 둔다(사용자 결정). 줌으로는 화살표보다 약 0.7단계 늦다.
const lineIconMinLineLength = 120.0;

/// 선 아이콘을 놓는 자리(출발 장소에서 선 길이의 몇 분의 몇). 화살표가 가운데(0.5)라서 겹치지 않는다.
const _lineIconAt = 0.25;

/// [from]에서 [to]로 가는 구간의 선 아이콘 자리. 두 점이 같으면 null이다.
///
/// [routeArrow]처럼 메르카토르 좌표에서 계산하고, [curvature]가 있으면 곡선 위(t = 0.25)에 놓는다.
RouteLineIconPlace? routeLineIcon(
  LatLng from,
  LatLng to, {
  double curvature = 0,
}) {
  final a = mercatorOf(from);
  final b = mercatorOf(to);
  final length = (b - a).distance;
  if (length == 0) return null;
  final control = quadraticControlPoint(a, b, curvature);
  return RouteLineIconPlace(
    position: latLngOfMercator(quadraticPoint(a, control, b, _lineIconAt)),
    minZoom: _zoomForLength(length, lineIconMinLineLength),
  );
}

/// 메르카토르 길이 [length](세계 지도 한 변 = 1)가 화면에서 [screenLength]가 되는 줌.
double _zoomForLength(
  double length, [
  double screenLength = arrowMinLineLength,
]) {
  final zoom = math.log(screenLength / (length * _worldSizeAtZoom0)) / math.ln2;
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

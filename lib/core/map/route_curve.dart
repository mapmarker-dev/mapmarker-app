import 'dart:math' as math;
import 'dart:ui';

import '../geometry/route_geometry.dart';
import 'geo.dart';
import 'route_arrow.dart';

/// 곡선 구간. 곡률 k 하나로 2차 베지어 곡선을 정한다(곡선은 구간마다 곡률 k 하나만 저장).
///
/// 제어점은 양 끝의 가운데에서 양 끝을 잇는 방향에 수직으로 (끝점 사이 길이 × k)만큼 떨어진 곳이다.
/// 곡선의 가운데(t = 0.5)는 그 절반만큼 휜다. k가 1이면 곡선 가운데가 끝점 사이 길이의 절반만큼 휜다(반원 가까이).

/// 곡률의 범위. 이보다 더 끌어도 끝에서 멈춘다.
const maxCurvature = 1.0;

/// 핸들을 직선에서 이만큼(논리 px) 안쪽으로 끌면 직선에 붙는다. 직선으로 되돌리는 버튼 대신이다.
const curveSnapDistance = 12.0;

/// 곡선을 이만큼의 토막으로 나눠 점으로 그린다. 화면에서 꺾인 곳이 보이지 않을 만큼이다.
const _curvePieces = 32;

/// [from]에서 [to]로 가는 구간을 그릴 점. 곡률이 0이면 양 끝 두 점이다.
///
/// 화면에 그려지는 모양과 맞추려고 메르카토르 좌표에서 계산한다([routeArrow]와 같다).
List<LatLng> routeCurvePoints(LatLng from, LatLng to, double curvature) {
  if (curvature == 0 || from == to) return [from, to];
  final a = mercatorOf(from);
  final b = mercatorOf(to);
  final control = quadraticControlPoint(a, b, curvature);
  return [
    from,
    for (var i = 1; i < _curvePieces; i++)
      latLngOfMercator(quadraticPoint(a, control, b, i / _curvePieces)),
    to,
  ];
}

/// 화면에서 곡선 가운데의 핸들을 [handle]로 끌었을 때의 곡률. [from]·[to]는 양 끝 장소의 화면 위치다.
///
/// 곡률은 끝점 사이 길이에 대한 비율이라, 메르카토르 좌표를 줄이고 돌린 화면 좌표에서 계산해도 같다.
/// 그래서 끄는 동안 지도에 좌표를 다시 묻지 않는다(기울인 지도는 원근 때문에 조금 어긋난다).
///
/// - 핸들을 끈 쪽으로 휜다. 곡선 가운데는 제어점의 절반만큼 휘므로, 제어점은 그 두 배 자리다.
/// - 직선에서 [curveSnapDistance]보다 가까우면 0(직선)이다.
/// - [maxCurvature]를 넘지 않는다. 양 끝이 같은 자리면 0이다.
double curvatureForHandle(Offset from, Offset to, Offset handle) {
  final chord = to - from;
  final length = chord.distance;
  if (length == 0) return 0;
  final normal = Offset(-chord.dy, chord.dx);
  final mid = (from + to) / 2;
  final pull = handle - mid;
  // 곡선 가운데가 직선에서 떨어진 거리(부호 있음).
  final bend = (pull.dx * normal.dx + pull.dy * normal.dy) / length;
  if (bend.abs() < curveSnapDistance) return 0;
  final curvature = 2 * bend / length;
  return curvature.clamp(-maxCurvature, maxCurvature);
}

/// 곡선 가운데(핸들 자리)의 화면 위치. [curvatureForHandle]의 반대다.
Offset curveMiddleOnScreen(Offset from, Offset to, double curvature) {
  final control = quadraticControlPoint(from, to, curvature);
  return quadraticPoint(from, control, to, 0.5);
}

/// 곡선 가운데에서 가는 방향(화면 좌표, 위가 0도이고 시계 방향). 핸들 안의 화살표가 이 방향을 가리킨다.
double curveBearingOnScreen(Offset from, Offset to, double curvature) {
  final control = quadraticControlPoint(from, to, curvature);
  final tangent = quadraticTangent(from, control, to, 0.5);
  final bearing = math.atan2(tangent.dx, -tangent.dy) * 180 / math.pi;
  return (bearing + 360) % 360;
}

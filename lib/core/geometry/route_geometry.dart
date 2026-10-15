import 'dart:ui';

/// 2차 베지어 곡선의 제어점. [k]는 곡률로, 0이면 직선이고 부호에 따라 휘는 방향이 바뀐다.
///
/// 화면 좌표는 이미 메르카토르 투영이므로 화면 좌표에서 계산해도 같다.
Offset quadraticControlPoint(Offset a, Offset b, double k) {
  final mid = (a + b) / 2;
  final d = b - a;
  final normal = Offset(-d.dy, d.dx);
  return mid + normal * k;
}

Offset quadraticPoint(Offset a, Offset c, Offset b, double t) {
  final u = 1 - t;
  return a * (u * u) + c * (2 * u * t) + b * (t * t);
}

Offset quadraticTangent(Offset a, Offset c, Offset b, double t) {
  return (c - a) * (2 * (1 - t)) + (b - c) * (2 * t);
}

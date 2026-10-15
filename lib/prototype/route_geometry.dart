import 'dart:typed_data';
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

/// 파일 앞부분의 시그니처로 이미지 형식을 판별한다.
String detectImageFormat(Uint8List bytes) {
  bool startsWith(List<int> sig) =>
      bytes.length >= sig.length &&
      List.generate(sig.length, (i) => bytes[i] == sig[i]).every((e) => e);

  if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'PNG';
  if (startsWith([0xFF, 0xD8, 0xFF])) return 'JPEG';
  if (bytes.length >= 12 &&
      startsWith([0x52, 0x49, 0x46, 0x46]) &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'WebP';
  }
  return 'unknown';
}

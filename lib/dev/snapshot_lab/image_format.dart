import 'dart:typed_data';

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

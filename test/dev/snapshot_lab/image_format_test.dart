import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/dev/snapshot_lab/image_format.dart';

void main() {
  test('PNG', () {
    expect(
      detectImageFormat(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D])),
      'PNG',
    );
  });

  test('JPEG', () {
    expect(
      detectImageFormat(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
      'JPEG',
    );
  });

  test('WebP', () {
    expect(
      detectImageFormat(
        Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits),
      ),
      'WebP',
    );
  });

  test('unknown', () {
    expect(detectImageFormat(Uint8List.fromList([1, 2])), 'unknown');
  });
}

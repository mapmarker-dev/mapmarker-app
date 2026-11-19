import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/photos/photo_preparer.dart';

/// JPEG 조각 하나: FF [marker], 길이(2바이트, 길이 칸 포함), [payload].
List<int> _segment(int marker, List<int> payload) {
  final length = payload.length + 2;
  return [0xFF, marker, length >> 8, length & 0xFF, ...payload];
}

/// SOI, [segments], 이미지 데이터 시작(SOS)과 끝(EOI)만 있는 JPEG 모양.
Uint8List _jpeg(List<List<int>> segments) => Uint8List.fromList([
  0xFF, 0xD8, // SOI
  for (final segment in segments) ...segment,
  ..._segment(0xDA, [0, 0, 0]), // SOS
  0x12, 0x34, // 이미지 데이터
  0xFF, 0xD9, // EOI
]);

final _jfif = _segment(0xE0, 'JFIF\u0000'.codeUnits);
final _exif = _segment(0xE1, [...'Exif\u0000\u0000'.codeUnits, 1, 2, 3]);
final _xmp = _segment(0xE1, 'http://ns.adobe.com/xap/1.0/\u0000'.codeUnits);
final _quantization = _segment(0xDB, List.filled(65, 1));

void main() {
  group('shortSideFor', () {
    test('긴 변이 상한이 되는 짧은 변을 준다 (가로, 세로 사진 모두)', () {
      // 4000×3000을 플러그인이 min(4000 / 1440, 3000 / 1440)로 나누면 1920×1440이다.
      expect(shortSideFor(4000, 3000, 1920), 1440);
      expect(shortSideFor(3000, 4000, 1920), 1440);
      expect(shortSideFor(1920, 1080, 400), 225);
    });

    test('이미 작은 사진은 키우지 않는다 (짧은 변 그대로면 플러그인이 1로 나눈다)', () {
      expect(shortSideFor(1200, 800, 1920), 800);
      expect(shortSideFor(1920, 1920, 1920), 1920);
    });

    test('아주 긴 사진도 1px보다 작게 만들지 않는다', () {
      expect(shortSideFor(100000, 10, 400), 1);
    });
  });

  group('hasMetadataSegment', () {
    test('EXIF나 XMP 조각(APP1)이 있으면 true', () {
      expect(hasMetadataSegment(_jpeg([_jfif, _exif, _quantization])), isTrue);
      expect(hasMetadataSegment(_jpeg([_xmp])), isTrue);
    });

    test('메타데이터 없는 JPEG는 false', () {
      expect(hasMetadataSegment(_jpeg([_jfif, _quantization])), isFalse);
      expect(hasMetadataSegment(_jpeg([])), isFalse);
    });

    test('이미지 데이터 뒤는 보지 않는다 (데이터 안의 FF E1을 조각으로 오해하지 않는다)', () {
      final jpeg = Uint8List.fromList([
        ..._jpeg([_jfif]).sublist(0, _jpeg([_jfif]).length - 2),
        0xFF, 0xE1, 0x00, 0x04, // 데이터 안에 우연히 있는 바이트
        0xFF, 0xD9,
      ]);

      expect(hasMetadataSegment(jpeg), isFalse);
    });

    test('JPEG가 아니거나 조각이 깨졌으면 PhotoPrepareException', () {
      expect(
        () => hasMetadataSegment(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])),
        throwsA(isA<PhotoPrepareException>()),
      );
      expect(
        () =>
            hasMetadataSegment(Uint8List.fromList([0xFF, 0xD8, 0x00, 0x00, 1])),
        throwsA(isA<PhotoPrepareException>()),
      );
      expect(
        () => hasMetadataSegment(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 1]),
        ),
        throwsA(isA<PhotoPrepareException>()),
      );
    });
  });

  group('checkPrepared', () {
    test('메타데이터가 없고 상한 안이면 통과한다', () {
      final jpeg = _jpeg([_jfif]);

      expect(() => checkPrepared(jpeg, jpeg), returnsNormally);
    });

    test('원본이나 썸네일에 위치 정보 조각이 남았으면 올리지 않는다', () {
      final clean = _jpeg([_jfif]);
      final withExif = _jpeg([_exif]);

      expect(
        () => checkPrepared(withExif, clean),
        throwsA(isA<PhotoPrepareException>()),
      );
      expect(
        () => checkPrepared(clean, withExif),
        throwsA(isA<PhotoPrepareException>()),
      );
    });

    test('서버 상한(원본 5MB, 썸네일 512KB)보다 크면 올리지 않는다', () {
      final clean = _jpeg([_jfif]);
      Uint8List padded(int size) =>
          Uint8List(size)..setRange(0, clean.length, clean);

      expect(
        () => checkPrepared(padded(photoMaxBytes + 1), clean),
        throwsA(isA<PhotoPrepareException>()),
      );
      expect(
        () => checkPrepared(clean, padded(thumbnailMaxBytes + 1)),
        throwsA(isA<PhotoPrepareException>()),
      );
    });
  });
}

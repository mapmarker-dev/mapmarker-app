import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/features/export/route_composer.dart';

Future<ui.Image> _solidImage(int width, int height, Color color) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(width, height);
}

Future<Color> _pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!;
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

void main() {
  testWidgets('composes onto the snapshot and encodes PNG at the same size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final base = await _solidImage(300, 500, Colors.grey);
      final composed = await composeRoute(
        base: base,
        points: const [Offset(50, 100), Offset(200, 250), Offset(100, 400)],
        names: const ['A', 'B', 'C'],
        title: '테스트',
        scale: 2,
      );
      final png = (await composed.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();

      expect(composed.width, 300);
      expect(composed.height, 500);
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });

  testWidgets('draws photo thumbnails above the stop', (tester) async {
    await tester.runAsync(() async {
      final base = await _solidImage(300, 300, Colors.grey);
      final photo = await _solidImage(40, 30, Colors.red);
      final composed = await composeRoute(
        base: base,
        points: const [Offset(150, 250)],
        names: const ['A'],
        title: '',
        scale: 1,
        photos: [photo],
      );

      // 썸네일 중심: 장소에서 위로 12 + 56 / 2 = 40px.
      expect(
        (await _pixel(composed, 150, 210)).toARGB32(),
        Colors.red.toARGB32(),
      );
    });
  });

  testWidgets('skips stops without a photo', (tester) async {
    await tester.runAsync(() async {
      final base = await _solidImage(400, 300, Colors.grey);
      final photo = await _solidImage(40, 30, Colors.red);
      final composed = await composeRoute(
        base: base,
        points: const [Offset(60, 250), Offset(200, 250), Offset(340, 250)],
        names: const ['A', 'B', 'C'],
        title: '',
        scale: 1,
        // 첫 번째 장소는 비우고 두 번째 장소에만 사진을 넣는다.
        photos: [null, photo, null],
      );

      expect(
        (await _pixel(composed, 60, 210)).toARGB32(),
        Colors.grey.toARGB32(),
      );
      expect(
        (await _pixel(composed, 200, 210)).toARGB32(),
        Colors.red.toARGB32(),
      );
      expect(
        (await _pixel(composed, 340, 210)).toARGB32(),
        Colors.grey.toARGB32(),
      );
    });
  });

  testWidgets('keeps the logo area untouched', (tester) async {
    await tester.runAsync(() async {
      final base = await _solidImage(300, 300, Colors.grey);
      const logoRect = Rect.fromLTWH(0, 250, 100, 50);
      final composed = await composeRoute(
        base: base,
        // 장소와 라벨이 로고 영역 위에 오도록 둔다.
        points: const [Offset(20, 280), Offset(80, 270)],
        names: const ['A', 'B'],
        title: '',
        scale: 1,
        logoRect: logoRect,
      );

      expect(
        (await _pixel(composed, 20, 280)).toARGB32(),
        Colors.grey.toARGB32(),
      );
      expect(
        (await _pixel(composed, 50, 275)).toARGB32(),
        Colors.grey.toARGB32(),
      );
    });
  });
}

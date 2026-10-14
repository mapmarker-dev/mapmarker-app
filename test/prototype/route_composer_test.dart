import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/prototype/route_composer.dart';
import 'package:mapmarker_app/prototype/route_geometry.dart';

Future<ui.Image> _blankImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.grey,
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  testWidgets('composes onto the snapshot and encodes PNG at the same size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final base = await _blankImage(300, 500);
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
      expect(detectImageFormat(png), 'PNG');
    });
  });
}

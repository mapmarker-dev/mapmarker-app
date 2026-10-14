import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/prototype/export_ratio.dart';

void main() {
  test('pixel sizes are 1080 wide', () {
    expect(ExportRatio.square.pixelSize, const Size(1080, 1080));
    expect(ExportRatio.portrait.pixelSize, const Size(1080, 1350));
    expect(ExportRatio.story.pixelSize, const Size(1080, 1920));
  });

  test('logical size times device pixel ratio gives the pixel size', () {
    for (final dpr in [2.0, 2.625, 3.0]) {
      final logical = ExportRatio.story.logicalSize(dpr);
      expect(logical.width * dpr, closeTo(1080, 0.001));
      expect(logical.height * dpr, closeTo(1920, 0.001));
    }
  });
}

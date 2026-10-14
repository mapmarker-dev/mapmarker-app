import 'dart:ui';

/// 내보내기 이미지 비율. 가로는 [exportWidth] px로 고정한다.
enum ExportRatio {
  square('1:1', 1, 1),
  portrait('4:5', 4, 5),
  story('9:16', 9, 16);

  const ExportRatio(this.label, this.width, this.height);

  final String label;
  final int width;
  final int height;

  static const exportWidth = 1080;

  /// 결과 이미지 크기 (px).
  Size get pixelSize => Size(
    exportWidth.toDouble(),
    (exportWidth * height / width).roundToDouble(),
  );

  /// 지도 위젯을 띄울 논리 크기. 이 크기로 띄우면 스냅샷이 [pixelSize]가 된다.
  Size logicalSize(double devicePixelRatio) => pixelSize / devicePixelRatio;
}

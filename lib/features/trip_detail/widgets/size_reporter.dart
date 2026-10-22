import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 자식의 크기가 정해지거나 바뀌면 다음 프레임에 알려 준다.
///
/// 지도 위에 띄운 요소의 높이를 지도 여백에 넣는 데 쓴다. 글자 크기 설정에 따라 높이가 달라져서 재야 한다.
class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({super.key, required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderSizeReporter).onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    final reported = _reported = size;
    // 레이아웃 중에는 다시 그리라고 할 수 없어서 다음 프레임에 알린다.
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}

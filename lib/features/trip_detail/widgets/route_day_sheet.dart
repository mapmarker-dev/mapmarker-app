import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'size_reporter.dart';

/// 일차 동선 시트. 세로·좁은 화면에서 지도 아래에서 끌어 올리면 그날의 장소와 구간이 나온다.
///
/// 손잡이와 제목 줄([header])을 끌면 시트 크기가 바뀌고, 목록([list])을 끌면 시트 크기는 그대로 두고 목록만 넘어간다.
/// 그래서 40%에서도 목록을 넘겨 아래 장소를 볼 수 있다.
///
/// 접으면 제목 줄([onHeaderSize]로 높이를 알린다)만 보인다. 더 올린 높이는 멈췄을 때만
/// [onLift]로 알린다. 끄는 동안 매 프레임 지도에 넘기면 네이티브 지도가 버벅인다.
class RouteDaySheet extends StatefulWidget {
  const RouteDaySheet({
    super.key,
    required this.controller,
    required this.headerHeight,
    required this.header,
    required this.list,
    required this.onHeaderSize,
    required this.onLift,
  });

  final DraggableScrollableController controller;

  /// 제목 줄 높이. 접힌 시트는 이 높이에 아래 시스템 여백을 더한 만큼 보인다.
  final double headerHeight;

  final Widget header;
  final Widget list;

  final ValueChanged<double> onHeaderSize;

  /// 접힌 높이보다 더 올라온 높이(논리 px).
  final ValueChanged<double> onLift;

  /// 시트를 펼쳤을 때 높이(화면 높이에 대한 비율). 가운데 멈추는 높이도 둔다.
  static const maxSize = 0.7;
  static const midSize = 0.4;

  @override
  State<RouteDaySheet> createState() => RouteDaySheetState();
}

/// 시트가 [extent](화면 높이 [height]에 대한 비율)에 있을 때, 접힌 높이([minSize])보다 더 올라온 높이(논리 px).
///
/// 시트가 멈추는 높이(접힘·가운데·최대) 근처일 때만 값을 내고, 그 사이를 지나는 중이면 null이다.
/// 값은 지금 높이가 아니라 그 멈추는 높이로 낸다. 접힘이면 정확히 0이다.
@visibleForTesting
double? sheetLiftAt(
  double extent, {
  required double minSize,
  required double height,
}) {
  const tolerance = 0.002;
  for (final size in [minSize, RouteDaySheet.midSize, RouteDaySheet.maxSize]) {
    if ((extent - size).abs() < tolerance) return (size - minSize) * height;
  }
  return null;
}

class RouteDaySheetState extends State<RouteDaySheet> {
  /// 화면 높이에 대한 접힌 시트의 비율. 그릴 때 정한다.
  double _minSize = 0.1;
  double _height = 0;

  static const _moveDuration = Duration(milliseconds: 250);

  /// 시트를 접는다. 지도 빈 곳을 누를 때 쓴다.
  void collapse() {
    if (!widget.controller.isAttached) return;
    widget.controller.animateTo(
      _minSize,
      duration: _moveDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// 목록이 보이게 가운데 높이(40%)까지 올린다. 이미 그보다 높으면 그대로 둔다.
  Future<void> reveal() async {
    if (!widget.controller.isAttached) return;
    if (widget.controller.size >= RouteDaySheet.midSize) return;
    await widget.controller.animateTo(
      RouteDaySheet.midSize,
      duration: _moveDuration,
      curve: Curves.easeOutCubic,
    );
  }

  bool _onExtent(DraggableScrollableNotification notification) {
    final lift = sheetLiftAt(
      notification.extent,
      minSize: _minSize,
      height: _height,
    );
    if (lift != null) widget.onLift(lift);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _height = constraints.maxHeight;
        final peek = widget.headerHeight + insets.bottom;
        _minSize = (peek / _height).clamp(0.05, RouteDaySheet.midSize - 0.05);
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: _onExtent,
          child: DraggableScrollableSheet(
            controller: widget.controller,
            initialChildSize: _minSize,
            minChildSize: _minSize,
            maxChildSize: RouteDaySheet.maxSize,
            snap: true,
            snapSizes: const [RouteDaySheet.midSize],
            builder: (context, scrollController) =>
                _sheet(context, scrollController),
          ),
        );
      },
    );
  }

  Widget _sheet(BuildContext context, ScrollController scrollController) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.lg.topLeft),
        side: BorderSide(color: context.appColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 손잡이와 제목 줄. 시트의 스크롤 컨트롤러는 여기에만 붙인다.
          // 그래서 이 줄을 끌면 시트 크기가 바뀌고(멈추는 높이에 맞춘다), 목록을 끌면 목록만 넘어간다.
          // 넘길 내용이 없는 줄이라 끄는 만큼 모두 시트 크기로 간다.
          // 시트 컨트롤러는 어딘가에 붙어 있어야 animateTo가 동작한다.
          SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            child: SizeReporter(
              onSize: (size) => widget.onHeaderSize(size.height),
              child: widget.header,
            ),
          ),
          Expanded(child: widget.list),
        ],
      ),
    );
  }
}

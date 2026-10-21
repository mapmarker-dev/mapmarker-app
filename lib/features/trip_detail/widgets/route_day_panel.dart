import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 일차 동선 패널. 가로이고 넓은 화면에서 지도 오른쪽에 세로 전체로 붙는다.
///
/// 지도와 세로를 나눠 쓰지 않아서 중간 높이 없이 열기·닫기만 있다. 
/// 여닫기는 화면이 정하고(`RouteChoice.panelOpen`),
/// 이 위젯은 제목 줄([header])과 목록([list])을 세로로 놓는다.
/// 위·오른쪽은 시스템 여백만큼 띄운다.
class RouteDayPanel extends StatelessWidget {
  const RouteDayPanel({super.key, required this.header, required this.list});

  final Widget header;
  final Widget list;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: Border(left: BorderSide(color: context.appColors.cardBorder)),
      child: Padding(
        padding: EdgeInsets.only(top: insets.top, right: insets.right),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: list),
          ],
        ),
      ),
    );
  }
}

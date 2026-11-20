import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings/route_chips_store.dart';

/// 동선 페이지의 칩 두 줄을 접었는지. 접으면 지금 보기를 요약한 알약 하나만 남는다.
///
/// 모든 여행에 함께 쓰고 기기에 기억한다(여행마다 다시 접게 하지 않는다).
/// 기억한 값을 읽는 동안은 펼친 채다.
final routeChipsCollapsedProvider =
    NotifierProvider<RouteChipsCollapsedController, bool>(
      RouteChipsCollapsedController.new,
    );

class RouteChipsCollapsedController extends Notifier<bool> {
  /// 기억한 값을 다 읽기 전에 사용자가 바꿨다. 늦게 온 값으로 덮지 않는다.
  bool _changed = false;

  @override
  bool build() {
    _changed = false;
    ref.watch(routeChipsStoreProvider).isCollapsed().then((collapsed) {
      if (ref.mounted && !_changed) state = collapsed;
    });
    return false;
  }

  void toggle() {
    _changed = true;
    state = !state;
    ref.read(routeChipsStoreProvider).setCollapsed(state);
  }
}

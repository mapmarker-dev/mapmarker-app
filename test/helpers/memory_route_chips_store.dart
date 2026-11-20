import 'package:mapmarker_app/data/settings/route_chips_store.dart';

/// 기기 대신 메모리에 칩을 접었는지 기억한다.
class MemoryRouteChipsStore implements RouteChipsStore {
  MemoryRouteChipsStore({this.collapsed = false});

  bool collapsed;

  @override
  Future<bool> isCollapsed() async => collapsed;

  @override
  Future<void> setCollapsed(bool collapsed) async {
    this.collapsed = collapsed;
  }
}

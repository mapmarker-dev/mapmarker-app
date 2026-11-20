import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 동선 페이지의 칩 두 줄을 접어 두었는지 이 기기에 기억한다. 모든 여행에 함께 쓴다.
abstract interface class RouteChipsStore {
  /// 접어 두었는지. 읽지 못하면 false다(펼친 칩이 보여도 해가 없다).
  Future<bool> isCollapsed();

  /// 기억한다. 기억하지 못해도 던지지 않는다(이번에는 바꾼 대로 두고, 다음에 켜면 전 상태다).
  Future<void> setCollapsed(bool collapsed);
}

class PrefsRouteChipsStore implements RouteChipsStore {
  PrefsRouteChipsStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'route_chips_collapsed';

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> isCollapsed() async {
    try {
      return await _prefs.getBool(_key) ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> setCollapsed(bool collapsed) async {
    try {
      await _prefs.setBool(_key, collapsed);
    } on Object {
      // 이번에는 바꾼 대로 둔다.
    }
  }
}

final routeChipsStoreProvider = Provider<RouteChipsStore>(
  (ref) => PrefsRouteChipsStore(),
);

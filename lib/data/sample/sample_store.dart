import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 샘플 여행을 숨겼는지(지웠거나 내 여행으로 썼는지) 이 기기에 기억한다.
///
/// 계정이 아니라 기기에 둔다. 서버에 기억하려면 서버를 고쳐야 해서다(OVERVIEW).
/// 앱을 다시 깔거나 다른 기기에서는 샘플이 다시 보인다.
abstract interface class SampleStore {
  /// 숨겼는지. 읽지 못하면 false다(샘플이 한 번 더 보여도 해가 없다).
  Future<bool> isHidden();

  /// 숨긴 것을 기억한다. 기억하지 못해도 던지지 않는다(이번에는 숨고, 다음에 켜면 다시 보인다).
  Future<void> hide();
}

class PrefsSampleStore implements SampleStore {
  PrefsSampleStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'sample_jeju_hidden';

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> isHidden() async {
    try {
      return await _prefs.getBool(_key) ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> hide() async {
    try {
      await _prefs.setBool(_key, true);
    } on Object {
      // 이번에는 숨은 채로 둔다.
    }
  }
}

final sampleStoreProvider = Provider<SampleStore>((ref) => PrefsSampleStore());

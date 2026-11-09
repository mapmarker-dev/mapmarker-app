import 'package:mapmarker_app/data/auth/auth_tokens.dart';
import 'package:mapmarker_app/data/auth/token_store.dart';

/// 메모리에만 두는 토큰 저장소.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.tokens]);

  AuthTokens? tokens;

  /// 켜면 저장에 실패한다.
  bool failWrites = false;

  /// 켜면 지우기에 실패한다.
  bool failClears = false;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens value) async {
    if (failWrites) throw Exception('저장 실패');
    tokens = value;
  }

  @override
  Future<void> clear() async {
    if (failClears) throw Exception('지우기 실패');
    tokens = null;
  }
}

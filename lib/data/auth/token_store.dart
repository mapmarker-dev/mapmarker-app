import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_tokens.dart';

/// 기기에 저장한 토큰.
abstract interface class TokenStore {
  /// 저장한 토큰. 없거나 읽지 못하면 null이다(로그아웃 상태로 본다).
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// 두 토큰을 한 키에 함께 둔다. 따로 두면 저장 중에 앱이 죽었을 때 짝이 어긋난다.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore([this._storage = const FlutterSecureStorage()]);

  static const storageKey = 'auth_tokens';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    try {
      final saved = await _storage.read(key: storageKey);
      return saved == null ? null : AuthTokens.tryFromJson(jsonDecode(saved));
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) =>
      _storage.write(key: storageKey, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/auth/auth_tokens.dart';
import 'package:mapmarker_app/data/auth/token_store.dart';

class _BrokenStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(code: 'keystore');
}

void main() {
  const tokens = AuthTokens(accessToken: 'a', refreshToken: 'r');

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('아무것도 저장하지 않았으면 null이다', () async {
    expect(await const SecureTokenStore().read(), isNull);
  });

  test('저장한 두 토큰을 다시 읽는다', () async {
    await const SecureTokenStore().write(tokens);

    final saved = await const SecureTokenStore().read();

    expect(saved?.accessToken, 'a');
    expect(saved?.refreshToken, 'r');
  });

  test('지우면 null이다', () async {
    await const SecureTokenStore().write(tokens);

    await const SecureTokenStore().clear();

    expect(await const SecureTokenStore().read(), isNull);
  });

  test('저장소를 읽지 못하면 null이다(로그아웃 상태)', () async {
    expect(await SecureTokenStore(_BrokenStorage()).read(), isNull);
  });

  test('저장한 값이 깨졌으면 null이다', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureTokenStore.storageKey: '{깨진 값',
    });

    expect(await const SecureTokenStore().read(), isNull);
  });
}

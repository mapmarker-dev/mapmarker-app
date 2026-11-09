import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'social_sdk.dart';

/// 로그인 실패. 화면이 고르는 안내가 셋이라 셋으로 나눈다.
enum LoginFailure {
  /// 인터넷 연결을 확인하게 한다.
  network,

  /// 서버가 제공자(카카오·네이버)에 닿지 못했다. 잠시 후 다시.
  unavailable,

  /// 그 밖의 실패. 다시 시도.
  rejected,
}

class LoginException implements Exception {
  const LoginException(this.failure);

  final LoginFailure failure;

  @override
  String toString() => 'LoginException($failure)';
}

class LoginResult {
  const LoginResult({required this.isNewUser});

  /// 이번 로그인으로 계정을 처음 만들었다.
  final bool isNewUser;
}

/// 소셜 로그인과 로그아웃. 제공자 SDK, 서버, 기기 토큰을 차례로 다룬다.
class Account {
  Account({required this._session, required this._api, required this._sdk});

  final AuthSession _session;
  final AuthApi _api;
  final SocialSdk _sdk;

  /// 제공자 토큰을 받아 서버에 로그인한다. 사용자가 취소하면 null이다.
  /// 실패하면 [LoginException]을 던진다.
  Future<LoginResult?> logIn(SocialProvider provider) async {
    final String? providerToken;
    try {
      providerToken = await _sdk.signIn(provider);
    } on SocialSdkException catch (error) {
      throw LoginException(
        error.network ? LoginFailure.network : LoginFailure.rejected,
      );
    }
    if (providerToken == null) return null;

    final LoginResponse response;
    try {
      response = await _api.login(provider, providerToken);
    } on ApiException catch (error) {
      throw LoginException(switch (error.failure) {
        ApiFailure.network => LoginFailure.network,
        ApiFailure.unavailable => LoginFailure.unavailable,
        _ => LoginFailure.rejected,
      });
    }
    await _session.signIn(response.tokens);
    return LoginResult(isNewUser: response.isNewUser);
  }

  /// 기기 토큰을 지우고 서버에 알린 뒤 SDK에서도 로그아웃한다.
  Future<void> logOut() async {
    await _session.logOut();
    await _sdk.signOut();
  }
}

final accountProvider = Provider<Account>(
  (ref) => Account(
    session: ref.watch(authSessionProvider),
    api: ref.watch(authApiProvider),
    sdk: ref.watch(socialSdkProvider),
  ),
);

import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import 'auth_api.dart';
import 'auth_tokens.dart';
import 'token_store.dart';

/// 이 기기의 로그인 상태와 토큰. 경로 표가 들으려고 [ChangeNotifier]다.
///
/// 기기에 토큰이 있으면 로그인 상태다. 켤 때 서버에 묻지 않는다(오프라인에서도 켜져야 한다).
class AuthSession extends ChangeNotifier {
  AuthSession({
    required this._store,
    required this._api,
    this._tokens,
  });

  static Future<AuthSession> restore({
    required TokenStore store,
    required AuthApi api,
  }) async => AuthSession(store: store, api: api, tokens: await store.read());

  final TokenStore _store;
  final AuthApi _api;
  AuthTokens? _tokens;
  int _generation = 0;
  Future<void>? _refreshing;

  bool get isLoggedIn => _tokens != null;

  String? get accessToken => _tokens?.accessToken;

  /// 로그인·로그아웃마다 바뀐다. 사용자가 바뀌었는지 알아보는 데 쓴다.
  int get generation => _generation;

  Future<void> signIn(AuthTokens tokens) async {
    _tokens = tokens;
    _generation++;
    await _save(tokens);
    notifyListeners();
  }

  /// 토큰을 새로 받아 저장한다. 진행 중인 재발급이 있으면 그것을 함께 기다린다.
  /// 서버는 동시에 온 재발급의 두 번째를 재사용으로 보고 로그인을 끊는다.
  ///
  /// 재발급의 401에서만 로그아웃한다. 네트워크 실패나 503으로는 토큰을 지우지 않는다.
  Future<void> refreshTokens() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  /// 진행 중인 재발급이 끝나길 기다린다. 재발급의 성공·실패는 묻지 않는다.
  Future<void> waitForRefresh() async {
    while (_refreshing != null) {
      try {
        await _refreshing;
      } on ApiException {
        // 재발급을 시작한 쪽이 받아 처리한다.
      }
    }
  }

  /// 진행 중인 재발급을 기다리고, 기기 토큰을 지운 뒤 서버에 알린다.
  /// 서버 로그아웃은 실패해도 무시한다. 세션은 만료되면 사라진다.
  Future<void> logOut() async {
    await waitForRefresh();
    final tokens = _tokens;
    if (tokens == null) return;
    await _end();
    try {
      await _api.logout(tokens.refreshToken);
    } on ApiException catch (error) {
      log('서버 로그아웃 실패: $error');
    }
  }

  Future<void> _refresh() async {
    final tokens = _tokens;
    if (tokens == null) throw const ApiException(ApiFailure.unauthorized);
    final AuthTokens next;
    try {
      next = await _api.refresh(tokens.refreshToken);
    } on ApiException catch (error) {
      if (error.failure == ApiFailure.unauthorized) await _end();
      rethrow;
    }
    _tokens = next;
    await _save(next);
  }

  /// 저장에 실패해도 메모리의 토큰으로 계속한다. 재발급으로 받은 토큰이면 예전 토큰은 이미 무효라서,
  /// 버리면 지금 바로 로그아웃된다. 이번 실행이 끝나면 다시 로그인해야 할 뿐이다.
  Future<void> _save(AuthTokens tokens) async {
    try {
      await _store.write(tokens);
    } on Exception catch (error) {
      log('토큰 저장 실패: ${error.runtimeType}');
    }
  }

  Future<void> _end() async {
    _tokens = null;
    _generation++;
    try {
      await _store.clear();
    } on Exception catch (error) {
      log('토큰 삭제 실패: ${error.runtimeType}');
    }
    notifyListeners();
  }
}

/// 앱을 켤 때 `main.dart`가 [AuthSession.restore]로 만들어 끼운다.
/// 경로 표가 첫 화면을 정하기 전에 로그인 상태를 알아야 해서다.
final authSessionProvider = Provider<AuthSession>(
  (ref) => throw UnimplementedError('main.dart에서 끼운다'),
);

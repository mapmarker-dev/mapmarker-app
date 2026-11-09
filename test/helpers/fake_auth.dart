import 'dart:async';

import 'package:mapmarker_app/data/auth/auth_api.dart';
import 'package:mapmarker_app/data/auth/auth_session.dart';
import 'package:mapmarker_app/data/auth/auth_tokens.dart';
import 'package:mapmarker_app/data/auth/social_sdk.dart';
import 'package:mapmarker_app/data/auth/token_store.dart';

import 'fake_http.dart';

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

/// 테스트용 로그인 토큰.
const testTokens = AuthTokens(accessToken: 'test-a', refreshToken: 'test-r');

/// 인증 서버 대신 답하는 가짜. 로그인은 [testTokens]를, 그 밖의 요청은 204를 준다.
FakeHttp fakeAuthServer({bool isNewUser = false}) => FakeHttp(
  (request) => request.uri.path.contains('/auth/login/')
      ? FakeReply.json(200, {
          ...tokenJson(testTokens.accessToken, testTokens.refreshToken),
          'isNewUser': isNewUser,
          'user': {'id': 'u', 'nickname': null, 'createdAt': ''},
        })
      : FakeReply.json(204),
);

/// 메모리 저장소를 쓰는 세션. [http]가 인증 서버 대신 답한다.
AuthSession testSession({bool loggedIn = true, FakeHttp? http}) => AuthSession(
  store: MemoryTokenStore(loggedIn ? testTokens : null),
  api: AuthApi(fakeDio(http ?? fakeAuthServer())),
  tokens: loggedIn ? testTokens : null,
);

/// 카카오·네이버 SDK 대신 쓰는 가짜. 기본으로 제공자 토큰 `provider-token`을 준다.
class FakeSocialSdk implements SocialSdk {
  /// 제공자 토큰을 정한다. null은 사용자 취소, [SocialSdkException]은 SDK 실패다.
  FutureOr<String?> Function(SocialProvider provider) onSignIn = (_) =>
      'provider-token';

  /// 로그아웃할 때 부른다.
  void Function() onSignOut = () {};

  /// 불린 순서. 예: `signIn kakao`, `signOut`.
  final calls = <String>[];

  @override
  Future<String?> signIn(SocialProvider provider) async {
    calls.add('signIn ${provider.name}');
    return onSignIn(provider);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    onSignOut();
  }
}

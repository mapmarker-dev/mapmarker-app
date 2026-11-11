import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/account.dart';
import '../../data/auth/social_sdk.dart';

/// 진행 중인 로그인의 제공자. 없으면 null이다.
final loginProvider = NotifierProvider<LoginController, SocialProvider?>(
  LoginController.new,
);

class LoginController extends Notifier<SocialProvider?> {
  @override
  SocialProvider? build() => null;

  /// 로그인한다. 알릴 실패를 돌려주고, 성공했거나 사용자가 취소했으면 null이다.
  /// 로그인하면 경로 표가 여행 목록으로 보낸다.
  Future<LoginFailure?> logIn(SocialProvider provider) async {
    if (state != null) return null;
    state = provider;
    try {
      await ref.read(accountProvider).logIn(provider);
      return null;
    } on LoginException catch (error) {
      return error.failure;
    } finally {
      state = null;
    }
  }
}

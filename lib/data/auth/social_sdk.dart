import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:naver_login_flutter/naver_login_flutter.dart';

enum SocialProvider { kakao, naver }

/// 카카오·네이버 SDK. 서버에 보낼 제공자 토큰을 받는다. 테스트는 가짜로 바꾼다.
abstract interface class SocialSdk {
  /// 카카오는 id_token, 네이버는 access token. 사용자가 취소하면 null이다.
  /// 실패하면 [SocialSdkException]을 던진다.
  Future<String?> signIn(SocialProvider provider);

  /// 이 기기에 남은 제공자 로그인을 끊는다. 실패는 무시한다.
  /// 연결 끊기(탈퇴)가 아니다.
  Future<void> signOut();
}

class SocialSdkException implements Exception {
  const SocialSdkException(this.message, {this.network = false});

  /// 개발자용 설명. 토큰 값을 넣지 않는다.
  final String message;

  /// 제공자에 닿지 못했다.
  final bool network;

  @override
  String toString() => 'SocialSdkException($message, network: $network)';
}

/// 실제 SDK. 네이버 값은 `AndroidManifest.xml`의 meta-data, 카카오 키는 `main.dart`의 `KakaoSdk.init`이 넣는다.
class PluginSocialSdk implements SocialSdk {
  const PluginSocialSdk();

  @override
  Future<String?> signIn(SocialProvider provider) => switch (provider) {
    SocialProvider.kakao => _kakao(),
    SocialProvider.naver => _naver(),
  };

  @override
  Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
    } on Exception catch (error) {
      // 카카오로 로그인하지 않았으면 토큰이 없다고 실패한다.
      log('카카오 로그아웃 실패: ${error.runtimeType}');
    }
    try {
      await FlutterNaverLogin.logOut();
    } on Exception catch (error) {
      log('네이버 로그아웃 실패: ${error.runtimeType}');
    }
  }

  Future<String?> _kakao() async {
    try {
      final token = await _kakaoToken();
      if (token == null) return null;
      return token.idToken ??
          (throw const SocialSdkException(
            '카카오 id_token 없음. 카카오 콘솔에서 OpenID Connect를 켠다',
          ));
    } on DioException catch (error) {
      throw SocialSdkException(
        '카카오 토큰 요청 실패: ${error.type}',
        network: error.response == null,
      );
    } on KakaoException catch (error) {
      throw SocialSdkException('카카오 로그인 실패: $error');
    } on PlatformException catch (error) {
      throw SocialSdkException('카카오 로그인 실패: ${error.code}');
    }
  }

  /// 카카오톡이 있으면 카카오톡으로, 없으면 카카오 계정으로 로그인한다. 취소하면 null이다.
  Future<OAuthToken?> _kakaoToken() async {
    if (await isKakaoTalkInstalled()) {
      try {
        return await UserApi.instance.loginWithKakaoTalk();
      } on Exception catch (error) {
        if (_isKakaoCancel(error)) return null;
        // 카카오톡에 로그인하지 않은 기기 등. 카카오 계정으로 다시 시도한다(카카오가 권하는 흐름).
        log('카카오톡 로그인 실패, 카카오 계정으로 시도: ${error.runtimeType}');
      }
    }
    try {
      return await UserApi.instance.loginWithKakaoAccount();
    } on Exception catch (error) {
      if (_isKakaoCancel(error)) return null;
      rethrow;
    }
  }

  static bool _isKakaoCancel(Exception error) => switch (error) {
    PlatformException(code: 'CANCELED') => true,
    KakaoClientException(reason: ClientErrorCause.cancelled) => true,
    _ => false,
  };

  Future<String?> _naver() async {
    final NaverLoginResult result;
    try {
      result = await FlutterNaverLogin.logIn();
    } on PlatformException catch (error) {
      throw SocialSdkException('네이버 로그인 실패: ${error.code}');
    }
    switch (result.status) {
      case NaverLoginStatus.loggedIn:
        final token = result.accessToken?.accessToken;
        if (token == null || token.isEmpty) {
          throw const SocialSdkException('네이버 access token 없음');
        }
        return token;
      case NaverLoginStatus.loggedOut:
        // 플러그인은 사용자 취소를 로그아웃 상태로 돌려준다.
        return null;
      case NaverLoginStatus.error:
        throw SocialSdkException('네이버 로그인 실패: ${result.errorMessage}');
    }
  }
}

final socialSdkProvider = Provider<SocialSdk>((ref) => const PluginSocialSdk());

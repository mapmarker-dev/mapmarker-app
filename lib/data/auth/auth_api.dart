import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import 'auth_tokens.dart';

/// access 토큰 없이 부르는 인증 API. 토큰을 붙이는 인터셉터가 없는 dio를 받는다.
/// 재발급 요청이 인터셉터를 거치면 재발급의 401이 다시 재발급을 부른다.
class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  /// 두 토큰을 새로 받는다. 저장은 부르는 쪽이 한다.
  Future<AuthTokens> refresh(String refreshToken) async {
    final Object? body = await _post('/auth/refresh', {
      'refreshToken': refreshToken,
    });
    return AuthTokens.tryFromJson(body) ??
        (throw const ApiException(ApiFailure.server));
  }

  /// 이 기기의 로그인을 끊는다. 모르는 토큰이어도 서버는 성공으로 답한다.
  Future<void> logout(String refreshToken) async {
    await _post('/auth/logout', {'refreshToken': refreshToken});
  }

  Future<Object?> _post(String path, Map<String, Object?> data) async {
    try {
      final response = await _dio.post<Object?>(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

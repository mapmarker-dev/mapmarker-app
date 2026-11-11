import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../auth/auth_api.dart';
import '../auth/auth_session.dart';
import 'api_exception.dart';

/// 서버 주소([apiBaseUrl], `/v1` 없이)를 쓰는 dio. 토큰은 붙이지 않는다.
///
/// 시간 제한이 있어야 한다. 재발급이 끝나지 않으면 기다리는 요청과 로그아웃이 모두 멈춘다.
/// 연결 제한은 짧게 둔다. 서버에 닿지 않을 때 저장 중 표시와 실패 안내를 오래 기다리지 않게 하려는 것이다.
Dio createDio(String apiBaseUrl) {
  final origin = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return Dio(
    BaseOptions(
      baseUrl: '$origin/v1',
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
}

/// 로그인이 필요한 서버 API. 응답 JSON을 돌려주고, 실패는 [ApiException]으로 던진다.
class ApiClient {
  ApiClient(this._dio, AuthSession session) {
    _dio.interceptors.add(_AuthInterceptor(session, _dio));
  }

  final Dio _dio;

  Future<Object?> get(String path) => _send(() => _dio.get<Object?>(path));

  Future<Object?> post(String path, {Object? data}) =>
      _send(() => _dio.post<Object?>(path, data: data));

  Future<Object?> patch(String path, {Object? data}) =>
      _send(() => _dio.patch<Object?>(path, data: data));

  Future<Object?> put(String path, {Object? data}) =>
      _send(() => _dio.put<Object?>(path, data: data));

  Future<Object?> delete(String path) =>
      _send(() => _dio.delete<Object?>(path));

  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// access 토큰을 붙이고, 401이면 재발급한 뒤 같은 요청을 한 번 다시 보낸다.
/// 재발급을 하나로 모으는 일은 [AuthSession.refreshTokens]가 한다.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._session, this._dio);

  static const _generationKey = 'authGeneration';
  static const _retriedKey = 'authRetried';

  final AuthSession _session;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _session.waitForRefresh();
    final token = _session.accessToken;
    if (token == null) {
      handler.reject(_failed(options, ApiFailure.unauthorized));
      return;
    }
    options.headers['Authorization'] = 'Bearer $token';
    options.extra[_generationKey] = _session.generation;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[_retriedKey] == true ||
        // 보낸 뒤 사용자가 바뀌었다. 다른 사용자의 토큰으로 다시 보내면 안 된다.
        options.extra[_generationKey] != _session.generation) {
      handler.next(err);
      return;
    }
    try {
      // 토큰이 그새 바뀌었으면 다른 요청이 이미 재발급한 것이다.
      final sent = options.headers['Authorization'];
      if (sent == 'Bearer ${_session.accessToken}') {
        await _session.refreshTokens();
      }
    } on ApiException catch (failure) {
      handler.next(DioException(requestOptions: options, error: failure));
      return;
    }
    options.extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (error) {
      handler.next(error);
    }
  }

  DioException _failed(RequestOptions options, ApiFailure failure) =>
      DioException(requestOptions: options, error: ApiException(failure));
}

/// 토큰을 붙이지 않는 인증 API.
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(createDio(Env.apiBaseUrl)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(createDio(Env.apiBaseUrl), ref.watch(authSessionProvider)),
);

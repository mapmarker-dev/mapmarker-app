import 'package:dio/dio.dart';

/// 서버 API 실패의 종류. 화면은 이것만 보고 알림을 고른다.
enum ApiFailure {
  /// 서버에 닿지 못했다(연결 실패, 시간 초과).
  network,

  /// 400: 입력이 틀렸다.
  badRequest,

  /// 401: 토큰이나 제공자 토큰이 틀렸다.
  unauthorized,

  /// 404: 없거나 남의 자원이다.
  notFound,

  /// 409: 중복 ID나 상태 충돌.
  conflict,

  /// 502·503·504: 서버나 제공자(카카오·네이버)에 잠시 닿지 못한다.
  unavailable,

  /// 그 밖의 서버 오류, 또는 알아볼 수 없는 응답.
  server,
}

class ApiException implements Exception {
  const ApiException(this.failure, {this.statusCode});

  factory ApiException.fromDio(DioException error) {
    if (error.error case final ApiException inner) return inner;
    final status = error.response?.statusCode;
    if (status == null) return const ApiException(ApiFailure.network);
    return ApiException(switch (status) {
      400 => ApiFailure.badRequest,
      401 => ApiFailure.unauthorized,
      404 => ApiFailure.notFound,
      409 => ApiFailure.conflict,
      502 || 503 || 504 => ApiFailure.unavailable,
      _ => ApiFailure.server,
    }, statusCode: status);
  }

  final ApiFailure failure;
  final int? statusCode;

  @override
  String toString() => 'ApiException($failure, $statusCode)';
}

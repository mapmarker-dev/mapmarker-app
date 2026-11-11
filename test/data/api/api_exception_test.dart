import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';

void main() {
  final request = RequestOptions(path: '/trips');

  ApiException fromStatus(int status) => ApiException.fromDio(
    DioException.badResponse(
      statusCode: status,
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: status),
    ),
  );

  test('나누는 상태 코드를 실패 종류로 바꾼다', () {
    expect(fromStatus(400).failure, ApiFailure.badRequest);
    expect(fromStatus(401).failure, ApiFailure.unauthorized);
    expect(fromStatus(404).failure, ApiFailure.notFound);
    expect(fromStatus(409).failure, ApiFailure.conflict);
    expect(fromStatus(503).failure, ApiFailure.unavailable);
    expect(fromStatus(500).failure, ApiFailure.server);
  });

  test('서버 앞단이 답한 502·504도 잠시 못 쓰는 것으로 본다', () {
    expect(fromStatus(502).failure, ApiFailure.unavailable);
    expect(fromStatus(504).failure, ApiFailure.unavailable);
  });

  test('상태 코드를 함께 남긴다', () {
    expect(fromStatus(409).statusCode, 409);
  });

  test('서버에 닿지 못하면 네트워크 실패다', () {
    for (final error in [
      DioException.connectionError(requestOptions: request, reason: 'test'),
      DioException.connectionTimeout(
        timeout: Duration.zero,
        requestOptions: request,
      ),
      DioException.receiveTimeout(
        timeout: Duration.zero,
        requestOptions: request,
      ),
      DioException(requestOptions: request),
    ]) {
      expect(ApiException.fromDio(error).failure, ApiFailure.network);
    }
  });

  test('인터셉터가 넣어 둔 실패는 그대로 꺼낸다', () {
    const inner = ApiException(ApiFailure.unavailable, statusCode: 503);

    final result = ApiException.fromDio(
      DioException(requestOptions: request, error: inner),
    );

    expect(result, same(inner));
  });
}

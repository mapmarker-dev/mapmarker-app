import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 실제 서버에 붙지 않는 dio 어댑터. 받은 요청을 기억하고 [handler]의 답을 돌려준다.
class FakeHttp implements HttpClientAdapter {
  FakeHttp(this.handler);

  /// 답을 정한다. [connectionError]를 던지면 네트워크 실패다.
  FutureOr<FakeReply> Function(RequestOptions request) handler;

  final requests = <RequestOptions>[];

  /// [path]로 끝나는 주소로 간 요청.
  List<RequestOptions> requestsTo(String path) => [
    for (final request in requests)
      if (request.uri.path.endsWith(path)) request,
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = await handler(options);
    return ResponseBody.fromString(
      reply.body,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [reply.contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [FakeHttp]의 답.
class FakeReply {
  const FakeReply.raw(
    this.status,
    this.body, {
    this.contentType = 'text/html; charset=utf-8',
  });

  FakeReply.json(this.status, [Object? json])
    : body = json == null ? '' : jsonEncode(json),
      contentType = Headers.jsonContentType;

  final int status;
  final String body;
  final String contentType;
}

/// 서버에 닿지 못한 실패.
DioException connectionError(RequestOptions request) =>
    DioException.connectionError(requestOptions: request, reason: 'test');

/// [FakeHttp]를 끼운 dio. 주소는 `createDio`와 같은 모양이다.
Dio fakeDio(FakeHttp http) =>
    Dio(BaseOptions(baseUrl: 'http://test/v1'))..httpClientAdapter = http;

/// 로그인·재발급 응답의 토큰 부분.
Map<String, Object?> tokenJson(String access, String refresh) => {
  'accessToken': access,
  'accessTokenExpiresAt': '2026-11-04T00:15:00.000Z',
  'refreshToken': refresh,
  'refreshTokenExpiresAt': '2026-12-04T00:00:00.000Z',
};

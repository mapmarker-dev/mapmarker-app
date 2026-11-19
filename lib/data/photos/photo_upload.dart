import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';

/// 올릴 준비가 된 사진. 앱이 줄이고 위치 정보(EXIF)를 지운 JPEG 두 개다(`photo_preparer.dart`).
///
/// [id]는 고를 때 만든다. 저장에 실패해 다시 저장해도 같은 사진이라, 서버가 같은 사진으로 알아본다.
@immutable
class PreparedPhoto {
  const PreparedPhoto({
    required this.id,
    required this.original,
    required this.thumbnail,
  });

  final String id;

  /// 긴 변 1920px 이하.
  final Uint8List original;

  /// 긴 변 400px 이하. 입력 화면의 미리보기에도 쓴다.
  final Uint8List thumbnail;

  @override
  String toString() =>
      'PreparedPhoto($id, ${original.length}B, ${thumbnail.length}B)';
}

/// 파일 하나를 올릴 S3 주소. [headers]를 그대로 붙여 PUT한다(서명에 들어가서 다르면 S3가 거절한다).
@immutable
class UploadTarget {
  const UploadTarget({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;
}

/// 서버가 준 업로드 주소(10분).
@immutable
class PhotoUploadTicket {
  const PhotoUploadTicket({
    required this.photoId,
    required this.original,
    required this.thumbnail,
  });

  final String photoId;
  final UploadTarget original;
  final UploadTarget thumbnail;
}

/// 서버가 서명한 주소로 S3에 파일을 직접 올린다.
///
/// 서버 dio(`ApiClient`)와 따로 된 dio를 쓴다. 우리 서버의 토큰이 S3로 나가면 안 되기 때문이다.
/// 실패는 [ApiException]이다(닿지 못함은 network, 그 밖은 S3 상태 코드대로).
class PhotoUploader {
  PhotoUploader(this._dio);

  final Dio _dio;

  Future<void> upload(UploadTarget target, Uint8List bytes) async {
    try {
      await _dio.put<void>(
        target.url,
        // 본문을 그대로 보낸다(dio가 JSON이나 폼으로 바꾸지 않게 스트림으로 넘긴다).
        data: Stream<List<int>>.value(bytes),
        options: Options(headers: target.headers),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// S3와 사진 주소용 dio. 원본(약 400KB)을 올리고 받는 시간을 넉넉히 둔다.
Dio createPhotoDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ),
);

/// 사진 파일을 주고받는 dio. 테스트는 가짜 HTTP를 끼운 dio로 바꾼다.
final photoDioProvider = Provider<Dio>((ref) {
  final dio = createPhotoDio();
  ref.onDispose(dio.close);
  return dio;
});

final photoUploaderProvider = Provider<PhotoUploader>(
  (ref) => PhotoUploader(ref.watch(photoDioProvider)),
);

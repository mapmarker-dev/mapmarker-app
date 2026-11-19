import 'dart:convert';
import 'dart:typed_data';

import 'package:mapmarker_app/data/photos/photo_images.dart';
import 'package:mapmarker_app/data/photos/photo_preparer.dart';
import 'package:mapmarker_app/data/photos/photo_source.dart';
import 'package:mapmarker_app/data/photos/photo_upload.dart';

/// 1×1 PNG. 이미지 위젯에 넣을 수 있는 가장 작은 그림이다.
final testImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// 사진 선택기 대신. [next]를 고른 것처럼 돌려준다(null이면 고르지 않고 닫음).
class FakePhotoSource implements PhotoSource {
  Uint8List? next = testImageBytes;

  /// 있으면 고르기가 이것으로 실패한다(예: 권한).
  Object? error;

  int picks = 0;

  @override
  Future<Uint8List?> pick() async {
    picks++;
    if (error case final error?) throw error;
    return next;
  }
}

/// 줄이기 대신. 받은 바이트를 그대로 원본과 썸네일로 쓴다.
class FakePhotoPreparer implements PhotoPreparer {
  /// 있으면 줄이기가 이것으로 실패한다(예: 읽지 못하는 형식).
  Object? error;

  final prepared = <PreparedPhoto>[];

  @override
  Future<PreparedPhoto> prepare(Uint8List source, {required String id}) async {
    if (error case final error?) throw error;
    final photo = PreparedPhoto(id: id, original: source, thumbnail: source);
    prepared.add(photo);
    return photo;
  }
}

/// 어떤 주소든 [testImageBytes]를 받는 사진 이미지. 받은 주소를 기억한다.
PhotoImages fakePhotoImages([List<String>? fetched]) =>
    PhotoImages((url) async {
      fetched?.add(url);
      return testImageBytes;
    });

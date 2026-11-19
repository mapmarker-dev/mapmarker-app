import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:mapmarker_app/data/photos/photo_images.dart';
import 'package:mapmarker_app/data/photos/photo_preparer.dart';
import 'package:mapmarker_app/data/photos/photo_source.dart';

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

/// 줄이기 대신. 받은 바이트를 그대로 원본과 썸네일로 쓰고, 크기는 [width]×[height]로 본다.
class FakePhotoPreparer implements PhotoPreparer {
  /// 있으면 줄이기가 이것으로 실패한다(예: 읽지 못하는 형식).
  Object? error;

  int width = 400;
  int height = 300;

  /// 썸네일을 만든 정사각형(원본 폭과 높이에 대한 비율).
  final areas = <Rect>[];

  /// 크기를 잰 원본(위치를 다시 고를 때 받은 것).
  final measured = <Uint8List>[];

  @override
  Future<SizedJpeg> shrink(Uint8List source) async {
    if (error case final error?) throw error;
    return SizedJpeg(source, width: width, height: height);
  }

  @override
  Future<SizedJpeg> measure(Uint8List original) async {
    measured.add(original);
    return SizedJpeg(original, width: width, height: height);
  }

  @override
  Future<Uint8List> squareThumbnail(SizedJpeg original, Rect area) async {
    areas.add(area);
    return original.bytes;
  }
}

/// 어떤 주소든 [testImageBytes]를 받는 사진 이미지. 받은 주소를 기억한다.
PhotoImages fakePhotoImages([List<String>? fetched]) =>
    PhotoImages((url) async {
      fetched?.add(url);
      return testImageBytes;
    });

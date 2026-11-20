import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/photo.dart';
import '../trips/trip_repository.dart';
import 'photo_upload.dart';

/// 사진 이미지를 받는다. 서버 dio가 아닌 [photoDioProvider]로 받는다(토큰을 S3로 보내지 않는다).
///
/// 사진 주소는 응답마다 새로 서명돼 바뀐다. 그래서 이미지([PhotoImage])는 주소가 아니라
/// 사진 ID와 크기로 기억한다. 여행을 다시 받아 주소가 바뀌어도 받아 둔 이미지를 그대로 쓴다.
class PhotoImages {
  PhotoImages(this._fetch, {this.onExpired});

  /// 주소의 바이트를 받는다. 테스트는 가짜로 바꾼다.
  final Future<Uint8List> Function(String url) _fetch;

  /// 주소의 유효 시간(1시간)이 지나 S3가 거절했다(403). 여행을 다시 받아 새 주소를 얻는다.
  final VoidCallback? onExpired;

  /// 지도 마커와 장소 줄.
  ImageProvider thumbnailOf(Photo photo) =>
      PhotoImage._(this, photo.id, photo.thumbnailUrl, thumbnail: true);

  /// 크게 볼 때.
  ImageProvider originalOf(Photo photo) =>
      PhotoImage._(this, photo.id, photo.url, thumbnail: false);

  Future<Uint8List> fetch(String url) async {
    try {
      return await _fetch(url);
    } on DioException catch (error) {
      if (error.response?.statusCode == 403) onExpired?.call();
      rethrow;
    }
  }
}

/// 사진 이미지. 같은 사진, 같은 크기면 주소가 달라도 같은 이미지로 본다(Flutter 이미지 캐시의 키).
///
/// 받지 못한 이미지는 캐시에 남지 않는다. 새 주소로 다시 받으려면 위젯의 key를 주소로 바꿔 새로 만든다
/// (같은 이미지로 보는 [Image]는 다시 받지 않는다).
@immutable
class PhotoImage extends ImageProvider<PhotoImage> {
  const PhotoImage._(
    this._images,
    this.photoId,
    this.url, {
    required this.thumbnail,
  });

  final PhotoImages _images;
  final String photoId;
  final String url;
  final bool thumbnail;

  @override
  Future<PhotoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(PhotoImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _load(key, decode),
        scale: 1,
        debugLabel: 'PhotoImage($photoId, ${thumbnail ? 'thumb' : 'full'})',
      );

  Future<ui.Codec> _load(PhotoImage key, ImageDecoderCallback decode) async {
    final bytes = await key._images.fetch(key.url);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is PhotoImage &&
      other.photoId == photoId &&
      other.thumbnail == thumbnail;

  @override
  int get hashCode => Object.hash(photoId, thumbnail);

  @override
  String toString() => 'PhotoImage($photoId, thumbnail: $thumbnail)';
}

/// 주소가 만료되면 보고 있는 여행을 다시 받는다. 여러 이미지가 한꺼번에 실패해도 30초에 한 번만.
final photoImagesProvider = Provider<PhotoImages>((ref) {
  final dio = ref.watch(photoDioProvider);
  DateTime? lastRefresh;
  return PhotoImages(
    (url) async {
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    },
    onExpired: () {
      final now = DateTime.now();
      if (lastRefresh != null &&
          now.difference(lastRefresh!) < const Duration(seconds: 30)) {
        return;
      }
      lastRefresh = now;
      ref.read(tripRepositoryProvider).refreshWatched();
    },
  );
});

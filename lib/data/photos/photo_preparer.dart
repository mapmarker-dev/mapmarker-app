import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_upload.dart';

/// 사진을 올릴 수 있게 줄인다.
///
/// 줄이기는 플랫폼 플러그인(`flutter_image_compress`)이 하고, 테스트는 가짜로 바꿔 끼운다.
/// 읽을 수 없는 사진이면 [PhotoPrepareException]이다.
abstract interface class PhotoPreparer {
  Future<PreparedPhoto> prepare(Uint8List source, {required String id});
}

/// 고른 사진을 읽거나 줄이지 못했다(지원하지 않는 형식, 깨진 파일 등).
class PhotoPrepareException implements Exception {
  const PhotoPrepareException(this.reason);

  final String reason;

  @override
  String toString() => 'PhotoPrepareException($reason)';
}

/// 원본의 긴 변(px). 휴대폰 화면에서 크게 봐도 충분하고 400KB 안팎이다.
const photoLongEdge = 1920;

/// 썸네일의 긴 변(px). 지도 마커와 목록(48dp)을 고해상도 화면에 그려도 충분하다.
const thumbnailLongEdge = 400;

/// 서버가 받는 최대 바이트 수(`mapmarker-server` `photo-rules.ts`와 같다).
const photoMaxBytes = 5 * 1024 * 1024;
const thumbnailMaxBytes = 512 * 1024;

/// 플러그인에 넘길 "최소 너비·높이". 플러그인은 `max(1, min(너비 / 값, 높이 / 값))`로 나누어 줄이므로,
/// 짧은 변을 넘기면 긴 변이 [longEdge]가 된다. 이미 작으면 그대로 둔다(키우지 않는다).
/// 같은 값을 너비와 높이에 넘겨서, 사진이 돌아가 있어도(EXIF 방향) 결과가 같다.
@visibleForTesting
int shortSideFor(int width, int height, int longEdge) {
  final long = math.max(width, height);
  final short = math.min(width, height);
  if (long <= longEdge) return short;
  return math.max(1, (short * longEdge / long).floor());
}

/// JPEG에 메타데이터 조각(APP1: EXIF나 XMP)이 있는지. 둘 다 위치를 담을 수 있다.
/// JPEG가 아니면 [PhotoPrepareException]이다.
///
/// 플러그인이 메타데이터를 지우지만, 올리기 전에 한 번 더 본다(플러그인 동작에 기대지 않으려고).
@visibleForTesting
bool hasMetadataSegment(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
    throw const PhotoPrepareException('JPEG가 아닙니다');
  }
  var position = 2;
  while (position + 4 <= jpeg.length) {
    if (jpeg[position] != 0xFF) {
      throw const PhotoPrepareException('JPEG 조각을 읽지 못했습니다');
    }
    final marker = jpeg[position + 1];
    // 채움 바이트.
    if (marker == 0xFF) {
      position++;
      continue;
    }
    // 이미지 데이터 시작(SOS)이나 끝(EOI). 메타데이터 조각은 그 앞에만 있다.
    if (marker == 0xDA || marker == 0xD9) return false;
    if (marker == 0xE1) return true;
    final length = (jpeg[position + 2] << 8) | jpeg[position + 3];
    if (length < 2) {
      throw const PhotoPrepareException('JPEG 조각 길이가 틀립니다');
    }
    position += 2 + length;
  }
  // 이미지 데이터 시작(SOS) 전에 끝났다. 잘린 파일이다.
  throw const PhotoPrepareException('JPEG가 잘렸습니다');
}

/// 줄인 두 파일이 올릴 수 있는지 본다. 위치 정보가 남았거나 서버 상한보다 크면 [PhotoPrepareException].
@visibleForTesting
void checkPrepared(Uint8List original, Uint8List thumbnail) {
  if (hasMetadataSegment(original) || hasMetadataSegment(thumbnail)) {
    throw const PhotoPrepareException('메타데이터가 남았습니다');
  }
  if (original.length > photoMaxBytes || thumbnail.length > thumbnailMaxBytes) {
    throw const PhotoPrepareException('줄인 사진이 너무 큽니다');
  }
}

/// 이미지 머리말만 읽어 크기를 잰다(전체를 풀지 않는다). 엔진이 모르는 형식이면 null.
Future<({int width, int height})?> readImageSize(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (width: descriptor.width, height: descriptor.height);
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// [PhotoPreparer]의 플러그인 구현.
class CompressPhotoPreparer implements PhotoPreparer {
  const CompressPhotoPreparer();

  @override
  Future<PreparedPhoto> prepare(Uint8List source, {required String id}) async {
    var input = source;
    var size = await readImageSize(input);
    if (size == null) {
      // 엔진이 모르는 형식(일부 HEIC). 플랫폼 디코더로 먼저 JPEG로 바꾼 뒤 잰다.
      input = await _compress(input, side: photoLongEdge, quality: 95);
      size = await readImageSize(input);
      if (size == null) throw const PhotoPrepareException('크기를 읽지 못했습니다');
    }
    final original = await _compress(
      input,
      side: shortSideFor(size.width, size.height, photoLongEdge),
      quality: 85,
    );
    final originalSize = await readImageSize(original);
    if (originalSize == null) {
      throw const PhotoPrepareException('줄인 사진을 읽지 못했습니다');
    }
    final thumbnail = await _compress(
      original,
      side: shortSideFor(
        originalSize.width,
        originalSize.height,
        thumbnailLongEdge,
      ),
      quality: 80,
    );
    checkPrepared(original, thumbnail);
    return PreparedPhoto(id: id, original: original, thumbnail: thumbnail);
  }

  /// EXIF 방향대로 돌린 뒤 메타데이터 없이 JPEG로 다시 쓴다.
  Future<Uint8List> _compress(
    Uint8List input, {
    required int side,
    required int quality,
  }) async {
    try {
      return await FlutterImageCompress.compressWithList(
        input,
        minWidth: side,
        minHeight: side,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
    } catch (error) {
      throw PhotoPrepareException('줄이지 못했습니다: $error');
    }
  }
}

final photoPreparerProvider = Provider<PhotoPreparer>(
  (ref) => const CompressPhotoPreparer(),
);

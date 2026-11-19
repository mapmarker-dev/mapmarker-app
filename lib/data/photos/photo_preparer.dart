import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 사진을 올릴 수 있게 만든다. 위치 정보(EXIF)가 없는 JPEG 두 개다.
///
/// 1. [shrink]: 고른 사진을 긴 변 1920px 원본으로 줄인다(비율 그대로).
/// 2. 사용자가 원본에서 정사각형 자리를 고른다("사진 위치" 화면).
/// 3. [squareThumbnail]: 그 자리로 400×400 썸네일을 만든다. 지도 마커, 장소 줄, 내보내기가 이것을 쓴다.
///
/// 줄이기는 플랫폼 플러그인(`flutter_image_compress`)이 하고, 테스트는 가짜로 바꿔 끼운다.
/// 읽을 수 없는 사진이면 [PhotoPrepareException]이다.
abstract interface class PhotoPreparer {
  /// 고른 사진(아무 형식, EXIF 방향 포함)을 원본으로 줄인다.
  Future<SizedJpeg> shrink(Uint8List source);

  /// 이미 줄여 올린 원본(서버에서 받은 것)의 크기. 위치를 다시 고를 때 쓴다.
  Future<SizedJpeg> measure(Uint8List original);

  /// [original]에서 [area](원본 폭과 높이에 대한 비율, 정사각형)를 잘라 썸네일을 만든다.
  Future<Uint8List> squareThumbnail(SizedJpeg original, ui.Rect area);
}

/// 크기를 아는 JPEG. 크기는 EXIF 방향을 적용한 뒤의 픽셀 수다(방향 정보는 지웠다).
@immutable
class SizedJpeg {
  const SizedJpeg(this.bytes, {required this.width, required this.height});

  final Uint8List bytes;
  final int width;
  final int height;
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

/// [area](폭과 높이에 대한 비율)를 [width]×[height] 사진의 픽셀 정사각형으로 바꾼다.
/// 한 변은 짧은 쪽에 맞추고, 사진 밖으로 나가지 않게 안으로 민다(고르는 화면의 반올림 오차).
@visibleForTesting
ui.Rect squarePixels(int width, int height, ui.Rect area) {
  final side = math.min(
    math.min(area.width * width, area.height * height),
    math.min(width, height).toDouble(),
  );
  final left = (area.left * width).clamp(0.0, width - side);
  final top = (area.top * height).clamp(0.0, height - side);
  return ui.Rect.fromLTWH(left, top, side, side);
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
  Future<SizedJpeg> shrink(Uint8List source) async {
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
    return measure(original);
  }

  @override
  Future<SizedJpeg> measure(Uint8List original) async {
    if (hasMetadataSegment(original)) {
      throw const PhotoPrepareException('메타데이터가 남았습니다');
    }
    final size = await readImageSize(original);
    if (size == null) throw const PhotoPrepareException('원본을 읽지 못했습니다');
    return SizedJpeg(original, width: size.width, height: size.height);
  }

  @override
  Future<Uint8List> squareThumbnail(SizedJpeg original, ui.Rect area) async {
    final crop = squarePixels(original.width, original.height, area);
    final side = math.min(thumbnailLongEdge, crop.width.floor());
    final png = await _drawSquare(original.bytes, crop, side);
    final thumbnail = await _compress(png, side: side, quality: 80);
    checkPrepared(original.bytes, thumbnail);
    return thumbnail;
  }

  /// 원본의 [crop] 부분을 [side]×[side]로 그려 PNG로 만든다(플러그인은 자르기가 없다).
  Future<Uint8List> _drawSquare(Uint8List jpeg, ui.Rect crop, int side) async {
    ui.Codec? codec;
    ui.Image? image;
    ui.Image? square;
    try {
      codec = await ui.instantiateImageCodec(jpeg);
      image = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final target = ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble());
      ui.Canvas(recorder, target).drawImageRect(
        image,
        crop,
        target,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      square = await recorder.endRecording().toImage(side, side);
      final data = await square.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const PhotoPrepareException('썸네일을 그리지 못했습니다');
      }
      return data.buffer.asUint8List();
    } on PhotoPrepareException {
      rethrow;
    } catch (error) {
      throw PhotoPrepareException('썸네일을 그리지 못했습니다: $error');
    } finally {
      square?.dispose();
      image?.dispose();
      codec?.dispose();
    }
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

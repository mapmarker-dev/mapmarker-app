import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

/// 사진첩에 저장한 결과.
enum GallerySaveResult {
  saved,

  /// 사진첩 권한이 없다(Android 10 이하, iOS). 앱 설정에서 켠다.
  denied,
  failed,
}

/// 만든 이미지를 기기 사진첩에 저장하거나 다른 앱으로 보낸다. 테스트는 가짜로 바꾼다(기기 사진첩과 공유 창에 붙지 않는다).
///
/// 이미지는 PNG로 받고 JPEG(품질 [jpegQuality])로 바꿔 내보낸다. 크기가 PNG의 몇 분의 일이고,
/// 메신저와 SNS도 어차피 다시 압축한다.
abstract interface class ImageSharing {
  /// 사진첩의 "MapMarker" 앨범에 저장한다. [name]은 확장자 없는 파일 이름이다.
  /// 권한이 없으면 먼저 묻는다.
  Future<GallerySaveResult> saveToGallery(
    Uint8List png, {
    required String name,
  });

  /// 시스템 공유 창을 띄운다. [origin]은 iPad에서 창이 붙을 곳(누른 버튼)이다. 실패하면 예외다.
  Future<void> share(Uint8List png, {required String name, Rect? origin});

  /// 사진첩 권한을 켜도록 앱 설정 화면을 연다.
  Future<void> openAppSettings();
}

const jpegQuality = 92;

/// 내보내는 이미지(1080px 안팎)보다 큰 최소 크기.
const _noShrink = 8192;

/// 사진첩 앨범 이름. 앱 이름이라 옮기지 않는다.
const _album = 'MapMarker';

final imageSharingProvider = Provider<ImageSharing>(
  (ref) => const DeviceImageSharing(),
);

/// gal(사진첩)과 share_plus(공유)로 내보낸다. Android와 iOS를 지원한다.
class DeviceImageSharing implements ImageSharing {
  const DeviceImageSharing();

  Future<Uint8List> _jpeg(Uint8List png) =>
      // 플러그인은 그림이 최소 크기보다 크면 줄인다(가로, 세로 비율 중 작은 쪽). 그림보다 큰 최소 크기를 줘서
      // 줄이지 않고 형식만 바꾼다.
      FlutterImageCompress.compressWithList(
        png,
        minWidth: _noShrink,
        minHeight: _noShrink,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

  @override
  Future<GallerySaveResult> saveToGallery(
    Uint8List png, {
    required String name,
  }) async {
    try {
      if (!await Gal.hasPermission(toAlbum: true) &&
          !await Gal.requestPermission(toAlbum: true)) {
        return GallerySaveResult.denied;
      }
      await Gal.putImageBytes(await _jpeg(png), album: _album, name: name);
      return GallerySaveResult.saved;
    } on GalException catch (error) {
      debugPrint('사진첩에 저장하지 못했습니다: ${error.type}');
      return error.type == GalExceptionType.permissionDenied
          ? GallerySaveResult.denied
          : GallerySaveResult.failed;
    } on Object catch (error) {
      debugPrint('사진첩에 저장하지 못했습니다: $error');
      return GallerySaveResult.failed;
    }
  }

  @override
  Future<void> share(
    Uint8List png, {
    required String name,
    Rect? origin,
  }) async {
    final file = XFile.fromData(
      await _jpeg(png),
      mimeType: 'image/jpeg',
      name: '$name.jpg',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: ['$name.jpg'],
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}

import 'dart:typed_data';
import 'dart:ui';

import 'package:mapmarker_app/core/share/image_sharing.dart';

/// 기기 사진첩과 공유 창 대신 받은 이미지를 들고 있는다.
class FakeImageSharing implements ImageSharing {
  FakeImageSharing({this.saveResult = GallerySaveResult.saved});

  /// 사진첩 저장의 결과.
  GallerySaveResult saveResult;

  /// 공유가 실패하게 한다.
  bool shareFails = false;

  /// 저장한 이미지의 (이름, PNG).
  final saved = <(String, Uint8List)>[];

  /// 공유한 이미지의 (이름, PNG).
  final shared = <(String, Uint8List)>[];

  int settingsOpened = 0;

  @override
  Future<GallerySaveResult> saveToGallery(
    Uint8List png, {
    required String name,
  }) async {
    if (saveResult == GallerySaveResult.saved) saved.add((name, png));
    return saveResult;
  }

  @override
  Future<void> share(
    Uint8List png, {
    required String name,
    Rect? origin,
  }) async {
    if (shareFails) throw StateError('공유 창을 띄우지 못함');
    shared.add((name, png));
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;
}

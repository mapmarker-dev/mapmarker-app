import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// 사진을 고르는 곳. 테스트는 가짜로 바꿔 끼운다.
abstract interface class PhotoSource {
  /// 고른 사진의 바이트. 고르지 않고 닫으면 null이다. 읽지 못하면 던진다.
  Future<Uint8List?> pick();
}

/// 시스템 사진 선택기(Android Photo Picker). 권한을 묻지 않는다.
/// 위치 정보는 여기서 받은 파일에 남아 있을 수 있어서, 올리기 전에 `PhotoPreparer`가 지운다.
class GalleryPhotoSource implements PhotoSource {
  const GalleryPhotoSource();

  @override
  Future<Uint8List?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // iOS에서 사진 전체 접근 권한을 묻지 않는다(메타데이터는 어차피 지운다).
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }
}

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => const GalleryPhotoSource(),
);

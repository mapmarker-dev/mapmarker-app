import 'package:flutter/foundation.dart';

/// 장소 사진. 지금은 장소마다 1장이다(나중에 여러 장으로 늘 수 있다).
///
/// 주소는 서버가 서명한 것이라 유효 시간(1시간)이 있다. 여행을 다시 받으면 새 주소가 온다.
/// 그래서 화면은 주소가 아니라 [id]로 이미지를 기억한다(`data/photos/photo_images.dart`).
@immutable
class Photo {
  const Photo({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
  });

  final String id;

  /// 원본(긴 변 1920px). 크게 볼 때와 내보내기에 쓴다.
  final String url;

  /// 썸네일(긴 변 400px). 지도 마커와 장소 줄에 쓴다.
  final String thumbnailUrl;

  @override
  bool operator ==(Object other) =>
      other is Photo &&
      other.id == id &&
      other.url == url &&
      other.thumbnailUrl == thumbnailUrl;

  @override
  int get hashCode => Object.hash(id, url, thumbnailUrl);

  @override
  String toString() => 'Photo($id)';
}

import 'package:flutter/foundation.dart';

/// 장소 사진. 지금은 장소마다 1장이지만, 여러 장으로 늘어날 수 있어 사진이 장소를 가리킨다.
@immutable
class Photo {
  const Photo({
    required this.id,
    required this.stopId,
    required this.storageKey,
  });

  final String id;
  final String stopId;

  /// S3 키.
  final String storageKey;
}

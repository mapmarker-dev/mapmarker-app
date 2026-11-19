import '../api/api_exception.dart';

/// 장소는 저장했지만 사진을 올리거나 지우지 못했다. 입력 화면은 "다시 저장해 주세요"로 알린다.
/// 다시 저장하면 장소와 사진을 함께 다시 보낸다(이미 된 것은 저장소가 건너뛴다).
class PhotoSaveException implements Exception {
  const PhotoSaveException(this.cause);

  final ApiException cause;

  @override
  String toString() => 'PhotoSaveException($cause)';
}

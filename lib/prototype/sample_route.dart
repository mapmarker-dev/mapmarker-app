import 'package:flutter_naver_map/flutter_naver_map.dart';

class SampleStop {
  const SampleStop(this.name, this.position);

  final String name;
  final NLatLng position;
}

/// 스냅샷 검증용 서울 동선.
const sampleStops = [
  SampleStop('경복궁', NLatLng(37.5796, 126.9770)),
  SampleStop('북촌한옥마을', NLatLng(37.5826, 126.9850)),
  SampleStop('서울시청', NLatLng(37.5666, 126.9780)),
  SampleStop('남산서울타워', NLatLng(37.5512, 126.9882)),
];

const sampleTitle = '서울 당일치기 테스트';

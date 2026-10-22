import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/map_provider_type.dart';
import 'map_provider.dart';
import 'naver/naver_map_provider.dart';

/// 지도 종류별 구현. 지도는 여행 단위로 정한다. 테스트에서는 가짜 지도로 바꿔 끼운다.
///
/// Riverpod의 Provider와 이름이 겹치지만, 문서의 `MapProvider`에 맞췄다.
final mapProviderProvider = Provider.family<MapProvider, MapProviderType>(
  (ref, type) => switch (type) {
    MapProviderType.naver => const NaverMapProvider(),
    // 1단계에는 구글 지도를 고르는 곳이 없다.
    MapProviderType.google => throw UnimplementedError('구글 지도는 2단계에 넣는다'),
  },
);

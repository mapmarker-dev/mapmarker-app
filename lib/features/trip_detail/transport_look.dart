import 'package:flutter/material.dart';

import '../../core/map/map_provider.dart';
import '../../data/models/segment.dart';

/// 이동 수단 아이콘. 일차 동선 목록, 이동 수단 입력 화면, 지도의 선 아이콘이 함께 쓴다.
IconData transportIcon(TransportMode mode) => switch (mode) {
  TransportMode.walk => Icons.directions_walk,
  TransportMode.subway => Icons.subway,
  TransportMode.bus => Icons.directions_bus,
  TransportMode.train => Icons.train,
  TransportMode.car => Icons.directions_car,
  TransportMode.flight => Icons.flight,
  TransportMode.ferry => Icons.directions_boat,
};

/// 갈아타는 구간을 지도에 그릴 때 고르는 순서. 앞일수록 그 구간을 대표한다.
///
/// 대략 먼 거리를 가는 수단부터다. 걸리는 시간은 비워 둘 수 있어서 시간으로 고르지 않는다
const _representativeOrder = [
  TransportMode.flight,
  TransportMode.ferry,
  TransportMode.train,
  TransportMode.subway,
  TransportMode.bus,
  TransportMode.car,
  TransportMode.walk,
];

/// 구간을 대표하는 수단. 예: 지하철 2정류장 + 도보 → 지하철, 비행기 + 지하철 → 비행기.
/// 이동 수단이 미정이면 null이다.
TransportMode? representativeMode(List<TransportLeg> legs) {
  final modes = {for (final leg in legs) leg.mode};
  return _representativeOrder.where(modes.contains).firstOrNull;
}

/// 지도의 선 모양. 일차는 색으로, 이동 수단은 선 모양과 아이콘으로 구분한다.
///
/// 7개를 모두 다른 모양으로 그리면 작은 화면에서 구분이 안 돼서 큰 갈래 3개만 두고,
/// 정확한 수단은 아이콘이 맡는다.
/// - 실선: 길(도로·철길)을 따라 타고 가는 차·버스·지하철·기차. 미정도 실선이다.
/// - 둥근 점선: 도보.
/// - 긴 파선: 길이 없는 하늘·바다를 건너는 비행기·배.
MapLineStyle lineStyleOf(TransportMode? mode) => switch (mode) {
  TransportMode.walk => MapLineStyle.dotted,
  TransportMode.flight || TransportMode.ferry => MapLineStyle.dashed,
  TransportMode.subway ||
  TransportMode.bus ||
  TransportMode.train ||
  TransportMode.car ||
  null => MapLineStyle.solid,
};

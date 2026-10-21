import 'package:flutter/material.dart';

import '../../data/models/segment.dart';

/// 이동 수단 아이콘. 일차 동선 목록과 이동 수단 입력 화면이 함께 쓴다.
IconData transportIcon(TransportMode mode) => switch (mode) {
  TransportMode.walk => Icons.directions_walk,
  TransportMode.subway => Icons.subway,
  TransportMode.bus => Icons.directions_bus,
  TransportMode.train => Icons.train,
  TransportMode.car => Icons.directions_car,
  TransportMode.flight => Icons.flight,
  TransportMode.ferry => Icons.directions_boat,
};

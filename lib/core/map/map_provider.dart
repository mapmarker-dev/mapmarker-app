import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'geo.dart';

/// 지도. 지도 종류(네이버, 구글)마다 구현이 하나씩 있고, 화면은 이 인터페이스만 쓴다.
///
/// 화면은 무엇을 그릴지([MapScene])만 넘긴다.
///
/// 아직 열지 않은 것: 마커·지도 탭(장소 편집 단위), 스냅샷과 좌표→화면 위치(1-5단계 내보내기).
abstract interface class MapProvider {
  Widget buildMap(MapScene scene);
}

/// 지도에 그릴 것.
@immutable
class MapScene {
  const MapScene({
    this.markers = const [],
    this.lines = const [],
    this.arrows = const [],
    required this.camera,
    this.padding = EdgeInsets.zero,
  });

  final List<MapMarker> markers;
  final List<MapLine> lines;
  final List<MapArrow> arrows;
  final MapCameraRequest camera;

  /// 지도 위를 덮는 화면 요소와 시스템 막대만큼의 여백.
  ///
  /// 지도는 이 여백 밑까지 그리지만, 로고와 카메라 맞춤은 이 안쪽에 온다.
  final EdgeInsets padding;
}

/// 카메라 요청. [key]가 바뀔 때만 [bounds]에 맞춘다.
///
/// 장소를 고쳐서 [bounds]가 바뀌어도 [key]가 같으면 카메라가 움직이지 않는다.
@immutable
class MapCameraRequest {
  const MapCameraRequest({required this.key, this.bounds});

  final Object key;

  /// null이면 움직이지 않는다.
  final LatLngBounds? bounds;
}

/// 마커. 그림은 [look]이고, 이름은 마커 아래 글자(캡션)로 보인다.
@immutable
class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.caption,
    required this.look,
  });

  final String id;
  final LatLng position;
  final String caption;
  final MarkerLook look;

  @override
  bool operator ==(Object other) =>
      other is MapMarker &&
      other.id == id &&
      other.position == position &&
      other.caption == caption &&
      other.look == look;

  @override
  int get hashCode => Object.hash(id, position, caption, look);
}

/// 마커 그림. 테두리 있는 원 가운데에 번호나 아이콘이 있고, 오른쪽 위에 작은 배지가 붙을 수 있다.
///
/// 같은 그림은 지도 구현이 한 번만 만들어 다시 쓴다.
@immutable
class MarkerLook {
  const MarkerLook({
    required this.fill,
    required this.foreground,
    required this.halo,
    this.label,
    this.icon,
    this.badge,
  });

  /// 원 바탕색.
  final Color fill;

  /// 번호·아이콘 색. 배지 아이콘도 이 색이다.
  final Color foreground;

  /// 테두리와 배지 바탕색. 지도 위에서 마커가 묻히지 않게 한다.
  final Color halo;

  /// 원 가운데 번호. 없으면 [icon]을 그린다.
  final String? label;
  final IconData? icon;

  /// 오른쪽 위 배지 아이콘.
  final IconData? badge;

  @override
  bool operator ==(Object other) =>
      other is MarkerLook &&
      other.fill == fill &&
      other.foreground == foreground &&
      other.halo == halo &&
      other.label == label &&
      other.icon == icon &&
      other.badge == badge;

  @override
  int get hashCode => Object.hash(fill, foreground, halo, label, icon, badge);
}

/// 선. 점 목록을 차례로 잇는다. 곡선도 앱이 점으로 계산해서 넘긴다.
@immutable
class MapLine {
  const MapLine({
    required this.id,
    required this.points,
    required this.color,
    required this.outline,
  });

  final String id;
  final List<LatLng> points;
  final Color color;

  /// 선 테두리 색. 지도 바탕 위에서 선이 묻히지 않게 한다.
  final Color outline;

  @override
  bool operator ==(Object other) =>
      other is MapLine &&
      other.id == id &&
      listEquals(other.points, points) &&
      other.color == color &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(id, Object.hashAll(points), color, outline);
}

/// 진행 방향 화살표. 지도와 함께 돌고, 기울이면 지도 바닥에 눕는다.
@immutable
class MapArrow {
  const MapArrow({
    required this.id,
    required this.position,
    required this.bearing,
    required this.color,
    required this.outline,
    this.minZoom = 0,
  });

  final String id;
  final LatLng position;

  /// 화살표가 가리키는 방향. 북쪽이 0도이고 시계 방향으로 잰다.
  final double bearing;

  final Color color;

  /// 화살표 테두리 색. 선 위에 놓여도 화살표 모양이 보이게 한다.
  final Color outline;

  /// 이 줌보다 멀리서 보면 숨긴다.
  final double minZoom;

  @override
  bool operator ==(Object other) =>
      other is MapArrow &&
      other.id == id &&
      other.position == position &&
      other.bearing == bearing &&
      other.color == color &&
      other.outline == outline &&
      other.minZoom == minZoom;

  @override
  int get hashCode =>
      Object.hash(id, position, bearing, color, outline, minZoom);
}

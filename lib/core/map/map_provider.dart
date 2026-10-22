import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'geo.dart';

/// 지도. 지도 종류(네이버, 구글)마다 구현이 하나씩 있고, 화면은 이 인터페이스만 쓴다.
///
/// 화면은 무엇을 그릴지([MapScene])와, 사용자가 누를 때 부를 함수를 넘긴다.
///
/// 아직 열지 않은 것: 스냅샷과 좌표→화면 위치(1-5단계 내보내기). 곡선 핸들은 화면 좌표가 필요하지만 지도 구현 안에서 끝낸다.
abstract interface class MapProvider {
  /// - [onMarkerTap]: 마커를 누르면 [MapMarker.id]로 부른다.
  /// - [onLineTap]: 선이나 선 아이콘을 누르면 [MapLine.id]([MapLineIcon.id])로 부른다. 화살표는 누를 수 없다.
  /// - [onMapTap]: 마커와 선이 아닌 곳을 누르면 부른다.
  /// - [onCurveChanged]: [MapScene.curveHandle]을 끌었다 놓으면 그 구간 ID와 새 곡률로 부른다.
  Widget buildMap(
    MapScene scene, {
    ValueChanged<String>? onMarkerTap,
    ValueChanged<String>? onLineTap,
    ValueChanged<MapTap>? onMapTap,
    void Function(String id, double curvature)? onCurveChanged,
  });
}

/// 지도를 누른 곳.
@immutable
class MapTap {
  const MapTap(this.position, {this.placeName});

  final LatLng position;

  /// 지도에 원래 있는 장소 이름(예: 네이버 지도의 심볼)을 눌렀으면 그 이름이다.
  final String? placeName;

  @override
  bool operator ==(Object other) =>
      other is MapTap &&
      other.position == position &&
      other.placeName == placeName;

  @override
  int get hashCode => Object.hash(position, placeName);

  @override
  String toString() => 'MapTap($position, $placeName)';
}

/// 지도에 그릴 것.
@immutable
class MapScene {
  const MapScene({
    this.markers = const [],
    this.lines = const [],
    this.arrows = const [],
    this.lineIcons = const [],
    this.curveHandle,
    required this.camera,
    this.padding = EdgeInsets.zero,
    this.logoLift = 0,
  });

  final List<MapMarker> markers;
  final List<MapLine> lines;
  final List<MapArrow> arrows;
  final List<MapLineIcon> lineIcons;

  /// 곡률을 고치는 핸들. 한 번에 한 구간에만 있다. 없으면 null이다.
  final MapCurveHandle? curveHandle;

  final MapCameraRequest camera;

  /// 지도 위를 덮는 화면 요소와 시스템 막대만큼의 여백.
  ///
  /// 지도는 이 여백 밑까지 그리지만, 로고와 카메라 맞춤은 이 안쪽에 온다.
  final EdgeInsets padding;

  /// 아래에서 올라온 화면 요소(예: 끌어 올린 시트)가 [padding]보다 더 덮는 높이.
  /// 로고만 이만큼 더 올린다. 지도 내용과 카메라는 그대로다.
  ///
  /// [padding]을 바꾸면 지도 내용이 함께 밀려서, 자주 바뀌는 높이는 여기로 넘긴다.
  final double logoLift;
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

/// 선 모양. 무늬 길이는 지도 구현이 정한다.
enum MapLineStyle {
  solid,

  /// 긴 파선.
  dashed,

  /// 둥근 점이 이어진 선.
  dotted,

  /// 가는 짧은 파선. 테두리가 없고, 누를 수 없고, 다른 선보다 아래에 그린다.
  /// 실제 구간이 아닌 연결(예: 숨긴 숙소를 거침)에 쓴다. 흐린 색은 [MapLine.color]로 넘긴다.
  faint,
}

/// 선. 점 목록을 차례로 잇는다. 곡선도 앱이 점으로 계산해서 넘긴다.
@immutable
class MapLine {
  const MapLine({
    required this.id,
    required this.points,
    required this.color,
    required this.outline,
    this.style = MapLineStyle.solid,
  });

  final String id;
  final List<LatLng> points;
  final Color color;

  /// 선 테두리 색. 지도 바탕 위에서 선이 묻히지 않게 한다.
  final Color outline;

  final MapLineStyle style;

  @override
  bool operator ==(Object other) =>
      other is MapLine &&
      other.id == id &&
      listEquals(other.points, points) &&
      other.color == color &&
      other.outline == outline &&
      other.style == style;

  @override
  int get hashCode =>
      Object.hash(id, Object.hashAll(points), color, outline, style);
}

/// 선에 붙는 작은 아이콘(예: 이동 수단). 둥근 네모 바탕에 아이콘이 있고, 지도를 돌려도 서 있다.
///
/// 누르면 그 선을 누른 것과 같다([MapProvider.buildMap]의 `onLineTap`을 [id]로 부른다).
@immutable
class MapLineIcon {
  const MapLineIcon({
    required this.id,
    required this.position,
    required this.icon,
    required this.background,
    required this.border,
    required this.foreground,
    this.minZoom = 0,
  });

  /// 붙은 선의 [MapLine.id].
  final String id;
  final LatLng position;
  final IconData icon;
  final Color background;
  final Color border;
  final Color foreground;

  /// 이 줌보다 멀리서 보면 숨긴다.
  final double minZoom;

  @override
  bool operator ==(Object other) =>
      other is MapLineIcon &&
      other.id == id &&
      other.position == position &&
      other.icon == icon &&
      other.background == background &&
      other.border == border &&
      other.foreground == foreground &&
      other.minZoom == minZoom;

  @override
  int get hashCode =>
      Object.hash(id, position, icon, background, border, foreground, minZoom);
}

/// 곡선 구간의 곡률을 고치는 핸들. 곡선 가운데에 진행 방향 화살표가 든 원으로 보이고, 끌면 곡선이 휜다.
///
/// 지도 구현이 그리고 끌기를 받는다. 끄는 동안의 미리보기도 지도 구현이 그리고, 놓으면 `onCurveChanged`로 새 곡률을 알린다.
@immutable
class MapCurveHandle {
  const MapCurveHandle({
    required this.id,
    required this.from,
    required this.to,
    required this.curvature,
    required this.color,
    required this.outline,
  });

  /// 구간의 [MapLine.id].
  final String id;
  final LatLng from;
  final LatLng to;

  /// 지금 곡률 k. 0이면 직선이다.
  final double curvature;

  /// 선 색. 핸들 테두리와 화살표, 끄는 동안의 미리보기 선 색이다.
  final Color color;

  /// 선 테두리 색. 핸들 바탕색이다.
  final Color outline;

  @override
  bool operator ==(Object other) =>
      other is MapCurveHandle &&
      other.id == id &&
      other.from == from &&
      other.to == to &&
      other.curvature == curvature &&
      other.color == color &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(id, from, to, curvature, color, outline);
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

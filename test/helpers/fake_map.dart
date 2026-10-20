import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';

/// 지도 SDK 없이 화면을 띄우는 가짜 지도. 받은 [MapScene]과 탭 함수를 그대로 들고 있는다.
class FakeMapProvider implements MapProvider {
  const FakeMapProvider();

  @override
  Widget buildMap(
    MapScene scene, {
    ValueChanged<String>? onMarkerTap,
    ValueChanged<String>? onLineTap,
    ValueChanged<MapTap>? onMapTap,
  }) => FakeMap(
    scene: scene,
    onMarkerTap: onMarkerTap,
    onLineTap: onLineTap,
    onMapTap: onMapTap,
  );
}

class FakeMap extends StatelessWidget {
  const FakeMap({
    super.key,
    required this.scene,
    this.onMarkerTap,
    this.onLineTap,
    this.onMapTap,
  });

  final MapScene scene;
  final ValueChanged<String>? onMarkerTap;
  final ValueChanged<String>? onLineTap;
  final ValueChanged<MapTap>? onMapTap;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

FakeMap _fakeMap(WidgetTester tester) =>
    tester.widget<FakeMap>(find.byType(FakeMap));

/// 지금 화면의 가짜 지도가 받은 것.
MapScene mapScene(WidgetTester tester) => _fakeMap(tester).scene;

/// 지도에 있는 마커를 누른 것처럼 한다.
Future<void> tapMarker(WidgetTester tester, String id) async {
  final map = _fakeMap(tester);
  expect(
    map.scene.markers.map((m) => m.id),
    contains(id),
    reason: '지도에 없는 마커는 누를 수 없다',
  );
  map.onMarkerTap!(id);
  await tester.pumpAndSettle();
}

/// 지도에 있는 선을 누른 것처럼 한다.
Future<void> tapLine(WidgetTester tester, String id) async {
  final map = _fakeMap(tester);
  expect(
    map.scene.lines.map((l) => l.id),
    contains(id),
    reason: '지도에 없는 선은 누를 수 없다',
  );
  map.onLineTap!(id);
  await tester.pumpAndSettle();
}

/// 지도의 빈 곳(또는 [placeName]이 있으면 지도에 원래 있는 장소 이름)을 누른 것처럼 한다.
Future<void> tapMap(
  WidgetTester tester,
  LatLng position, {
  String? placeName,
}) async {
  _fakeMap(tester).onMapTap!(MapTap(position, placeName: placeName));
  await tester.pumpAndSettle();
}

extension MapSceneLabels on MapScene {
  /// 마커 이름. 예: `['제주시 숙소', '용두암']`.
  List<String> get captions => [for (final m in markers) m.caption];
}

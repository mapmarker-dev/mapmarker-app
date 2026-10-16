import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';

/// 지도 SDK 없이 화면을 띄우는 가짜 지도. 받은 [MapScene]을 그대로 들고 있는다.
class FakeMapProvider implements MapProvider {
  const FakeMapProvider();

  @override
  Widget buildMap(MapScene scene) => FakeMap(scene: scene);
}

class FakeMap extends StatelessWidget {
  const FakeMap({super.key, required this.scene});

  final MapScene scene;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// 지금 화면의 가짜 지도가 받은 것.
MapScene mapScene(WidgetTester tester) =>
    tester.widget<FakeMap>(find.byType(FakeMap)).scene;

extension MapSceneLabels on MapScene {
  /// 마커 이름. 예: `['제주시 숙소', '용두암']`.
  List<String> get captions => [for (final m in markers) m.caption];
}

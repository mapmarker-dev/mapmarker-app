import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/map/route_arrow.dart';
import 'package:mapmarker_app/data/models/photo.dart';

/// 지도 SDK 없이 화면을 띄우는 가짜 지도. 받은 [MapScene]과 탭 함수를 그대로 들고 있는다.
///
/// 내보내기 지도([buildCaptureMap])는 그린 다음 프레임에 1×1 그림을 찍은 것으로 넘긴다.
/// 범위에 맞출 때는 여백 안쪽 가운데에 가로세로 같은 배율로 맞추고, 한 곳에 둘 때는 그곳이 가운데다([fakeCapture]).
/// [captureFails]면 찍지 않고 실패를 알린다.
class FakeMapProvider implements MapProvider {
  const FakeMapProvider({this.captureFails = false});

  final bool captureFails;

  @override
  Widget buildCaptureMap({
    required MapFrame frame,
    required ValueChanged<MapCapture> onCaptured,
    required VoidCallback onFailed,
  }) => FakeCaptureMap(
    frame: frame,
    onCaptured: onCaptured,
    onFailed: onFailed,
    fails: captureFails,
  );

  @override
  Widget buildMap(
    MapScene scene, {
    ValueChanged<String>? onMarkerTap,
    ValueChanged<String>? onLineTap,
    ValueChanged<MapTap>? onMapTap,
    Future<bool> Function(String id, double curvature)? onCurveChanged,
    void Function(String id, PhotoSide side)? onPhotoSideChanged,
  }) => FakeMap(
    scene: scene,
    onMarkerTap: onMarkerTap,
    onLineTap: onLineTap,
    onMapTap: onMapTap,
    onCurveChanged: onCurveChanged,
    onPhotoSideChanged: onPhotoSideChanged,
  );
}

class FakeMap extends StatelessWidget {
  const FakeMap({
    super.key,
    required this.scene,
    this.onMarkerTap,
    this.onLineTap,
    this.onMapTap,
    this.onCurveChanged,
    this.onPhotoSideChanged,
  });

  final MapScene scene;
  final ValueChanged<String>? onMarkerTap;
  final ValueChanged<String>? onLineTap;
  final ValueChanged<MapTap>? onMapTap;
  final Future<bool> Function(String id, double curvature)? onCurveChanged;
  final void Function(String id, PhotoSide side)? onPhotoSideChanged;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// 가짜 내보내기 지도. 범위가 바뀔 때마다 한 번 찍는다.
class FakeCaptureMap extends StatefulWidget {
  const FakeCaptureMap({
    super.key,
    required this.frame,
    required this.onCaptured,
    required this.onFailed,
    this.fails = false,
  });

  final MapFrame frame;
  final ValueChanged<MapCapture> onCaptured;
  final VoidCallback onFailed;
  final bool fails;

  @override
  State<FakeCaptureMap> createState() => _FakeCaptureMapState();
}

class _FakeCaptureMapState extends State<FakeCaptureMap> {
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(FakeCaptureMap old) {
    super.didUpdateWidget(old);
    if (old.frame != widget.frame) _schedule();
  }

  void _schedule() {
    final frame = widget.frame;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || frame != widget.frame) return;
      if (widget.fails) {
        widget.onFailed();
        return;
      }
      widget.onCaptured(fakeCapture(frame, context.size!));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// [size] 지도에 [frame]을 맞춰 찍은 것 같은 가짜 그림.
MapCapture fakeCapture(MapFrame frame, Size size) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFFEDEAE3),
  );
  final image = recorder.endRecording().toImageSync(1, 1);
  final (projection, zoom) = switch (frame) {
    MapFrame(:final bounds?) => _fitted(bounds, frame.padding, size),
    MapFrame(:final center, :final zoom) => (
      MapProjection.centered(center!, zoom!, size),
      zoom,
    ),
  };
  return MapCapture(
    image: image,
    frame: frame,
    projection: projection,
    zoom: zoom,
    logo: Rect.fromLTWH(0, size.height - 48, 112, 48),
  );
}

/// 실제 지도처럼 [bounds]를 [padding] 안쪽 가운데에 가로세로 같은 배율로 맞춘다.
(MapProjection, double) _fitted(
  LatLngBounds bounds,
  EdgeInsets padding,
  Size size,
) {
  final sw = mercatorOf(bounds.southWest);
  final ne = mercatorOf(bounds.northEast);
  final inner = padding.deflateRect(Offset.zero & size);
  final world = math.min(
    inner.width / (ne.dx - sw.dx),
    inner.height / (sw.dy - ne.dy),
  );
  final middle = (sw + ne) / 2;
  Offset at(Offset m) => inner.center + (m - middle) * world;
  return (
    MapProjection.fromPairs(
      (bounds.southWest, at(sw)),
      (bounds.northEast, at(ne)),
    ),
    math.log(world / 256) / math.ln2,
  );
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

/// 지도에 있는 선 아이콘(이동 수단)을 누른 것처럼 한다. 선을 누른 것과 같다.
Future<void> tapLineIcon(WidgetTester tester, String id) async {
  final map = _fakeMap(tester);
  expect(
    map.scene.lineIcons.map((i) => i.id),
    contains(id),
    reason: '지도에 없는 선 아이콘은 누를 수 없다',
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

/// 지도의 곡선 핸들을 끌어 [curvature]로 놓은 것처럼 한다. 핸들이 있어야 끌 수 있다.
/// 화면이 저장했는지 돌려준다. false면 지도가 끄는 동안의 미리보기를 지운다.
Future<bool> dragCurveHandle(WidgetTester tester, double curvature) async {
  final saved = releaseCurveHandle(tester, curvature);
  await tester.pumpAndSettle();
  return saved;
}

/// [dragCurveHandle]과 같지만 화면을 다시 그리지 않고 곧바로 돌아온다. 저장을 기다리는 동안을 볼 때 쓴다.
Future<bool> releaseCurveHandle(WidgetTester tester, double curvature) {
  final map = _fakeMap(tester);
  final handle = map.scene.curveHandle;
  expect(handle, isNotNull, reason: '곡선 핸들이 없으면 끌 수 없다');
  return map.onCurveChanged!(handle!.id, curvature);
}

/// 지도의 사진 방향 화살표 중 [side]를 누른 것처럼 한다. 화살표가 있어야 누를 수 있다.
Future<void> pickPhotoSide(WidgetTester tester, PhotoSide side) async {
  final map = _fakeMap(tester);
  final picker = map.scene.photoSidePicker;
  expect(picker, isNotNull, reason: '사진 방향 화살표가 없으면 누를 수 없다');
  map.onPhotoSideChanged!(picker!.id, side);
  await tester.pumpAndSettle();
}

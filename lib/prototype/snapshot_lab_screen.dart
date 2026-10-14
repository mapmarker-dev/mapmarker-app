import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:image_picker/image_picker.dart';

import 'export_ratio.dart';
import 'route_composer.dart';
import 'route_geometry.dart';
import 'sample_route.dart';

/// 네이버 로고 위치. 로고는 가리면 안 되므로 위치를 고정하고 합성할 때 이 영역을 지킨다.
const _logoMargin = EdgeInsets.symmetric(horizontal: 12, vertical: 16);

/// 로고와 여백을 넉넉히 감싸는 영역 (논리 px, 왼쪽 아래 기준).
const _logoReserve = Size(112, 48);

/// 동선을 화면에 맞출 때의 여백 (논리 px). 위는 제목과 사진, 아래는 로고 자리다.
const _routePadding = EdgeInsets.fromLTRB(48, 150, 64, 72);

/// 0단계 이미지 내보내기 검증 화면.
///
/// - 비율: 지도 위젯을 결과 이미지 크기(가로 1080px)로 띄우고, 화면에는 축소해서 보여 준다.
/// - 스냅샷: 지도 스냅샷만 찍어 형식과 해상도를 본다.
/// - SDK 오버레이: 켜고 스냅샷을 찍으면 SDK가 그린 마커·선이 이미지에 들어가는지 본다.
/// - 지도 가리기: 지도가 다른 위젯에 가려져 있어도 스냅샷이 찍히는지 본다.
/// - 사진: 고른 사진을 순서대로 장소에 붙여 썸네일로 그린다.
/// - 합성: 스냅샷 위에 Flutter Canvas로 동선과 사진을 그려 PNG로 저장한다.
class SnapshotLabScreen extends StatefulWidget {
  const SnapshotLabScreen({super.key});

  @override
  State<SnapshotLabScreen> createState() => _SnapshotLabScreenState();
}

class _SnapshotLabScreenState extends State<SnapshotLabScreen> {
  NaverMapController? _controller;
  ExportRatio _ratio = ExportRatio.portrait;
  List<ui.Image?> _photos = const [];
  bool _overlaysOn = false;
  bool _covered = false;
  bool _cameraIdle = false;
  bool _busy = false;

  bool get _ready => _controller != null && _cameraIdle && !_busy;

  double get _dpr => MediaQuery.devicePixelRatioOf(context);

  Size get _mapSize => _ratio.logicalSize(_dpr);

  void _changeRatio(ExportRatio ratio) {
    setState(() {
      _ratio = ratio;
      _controller = null;
      _cameraIdle = false;
    });
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _controller = controller;
    await _setOverlays(_overlaysOn);
    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        NLatLngBounds.from(sampleStops.map((s) => s.position)),
        padding: _routePadding,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _setOverlays(bool on) async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _overlaysOn = on);
    await controller.clearOverlays();
    if (!on) return;
    await controller.addOverlayAll({
      NPolylineOverlay(
        id: 'route',
        coords: sampleStops.map((s) => s.position),
        color: Colors.red,
        width: 4,
      ),
      for (final (i, stop) in sampleStops.indexed)
        NMarker(
          id: 'stop_$i',
          position: stop.position,
          caption: NOverlayCaption(text: '${i + 1}. ${stop.name}'),
        ),
    });
  }

  Future<void> _pickPhotos() async {
    final files = await ImagePicker().pickMultiImage(
      limit: sampleStops.length,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (files.isEmpty) return;
    final photos = <ui.Image?>[];
    for (final file in files.take(sampleStops.length)) {
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      photos.add((await codec.getNextFrame()).image);
    }
    setState(() => _photos = photos);
  }

  Future<(Uint8List, ui.Image, int)> _takeSnapshot() async {
    final watch = Stopwatch()..start();
    final file = await _controller!.takeSnapshot(compressQuality: 100);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final image = (await codec.getNextFrame()).image;
    return (bytes, image, watch.elapsedMilliseconds);
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _stateInfo =>
      'SDK 오버레이: ${_overlaysOn ? "켜짐" : "꺼짐"} / '
      '지도 가리기: ${_covered ? "켜짐" : "꺼짐"}';

  Future<void> _snapshot() async {
    final (bytes, image, ms) = await _takeSnapshot();
    _openResult('스냅샷 ${_ratio.label}', bytes, [
      '형식: ${detectImageFormat(bytes)}',
      ..._sizeInfo(image),
      '용량: ${_kb(bytes.length)}',
      '소요: $ms ms',
      _stateInfo,
    ]);
  }

  Future<void> _compose() async {
    final watch = Stopwatch()..start();
    final (_, base, snapshotMs) = await _takeSnapshot();
    final scale = base.width / _mapSize.width;
    final points = <Offset>[];
    for (final stop in sampleStops) {
      final p = await _controller!.latLngToScreenLocation(stop.position);
      points.add(Offset(p.x * scale, p.y * scale));
    }
    final logoRect = Rect.fromLTWH(
      0,
      base.height - _logoReserve.height * scale,
      _logoReserve.width * scale,
      _logoReserve.height * scale,
    );
    final composed = await composeRoute(
      base: base,
      points: points,
      names: sampleStops.map((s) => s.name).toList(),
      title: sampleTitle,
      scale: scale,
      photos: _photos,
      logoRect: logoRect,
    );
    final png = (await composed.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final file = File(
      '${Directory.systemTemp.path}/route_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(png);

    _openResult('합성 ${_ratio.label}', png, [
      '형식: ${detectImageFormat(png)}',
      ..._sizeInfo(composed),
      '배율(이미지 px / 논리 px): ${scale.toStringAsFixed(3)}',
      '사진: ${_photos.length}장',
      '용량: ${_kb(png.length)}',
      '소요: 스냅샷 $snapshotMs ms / 전체 ${watch.elapsedMilliseconds} ms',
      _stateInfo,
      '저장: ${file.path}',
    ]);
  }

  List<String> _sizeInfo(ui.Image image) {
    final target = _ratio.pixelSize;
    final screen = MediaQuery.sizeOf(context) * _dpr;
    final matches =
        (image.width - target.width).abs() <= 1 &&
        (image.height - target.height).abs() <= 1;
    return [
      '목표: ${target.width.toInt()} x ${target.height.toInt()} px',
      '결과: ${image.width} x ${image.height} px ${matches ? "(일치)" : "(불일치)"}',
      '지도 위젯: ${_mapSize.width.toStringAsFixed(1)} x ${_mapSize.height.toStringAsFixed(1)} 논리 px',
      '기기 화면: ${screen.width.round()} x ${screen.height.round()} px (픽셀 비율 $_dpr)',
    ];
  }

  String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

  void _openResult(String title, Uint8List bytes, List<String> info) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ResultScreen(title: title, bytes: bytes, info: info),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스냅샷 검증')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<ExportRatio>(
              segments: [
                for (final ratio in ExportRatio.values)
                  ButtonSegment(value: ratio, label: Text(ratio.label)),
              ],
              selected: {_ratio},
              onSelectionChanged: _busy ? null : (s) => _changeRatio(s.first),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                child: SizedBox.fromSize(
                  size: _mapSize,
                  child: Stack(
                    children: [
                      NaverMap(
                        // 비율이 바뀌면 지도를 새로 만든다.
                        key: ValueKey(_ratio),
                        options: const NaverMapViewOptions(
                          initialCameraPosition: NCameraPosition(
                            target: NLatLng(37.5669, 126.9826),
                            zoom: 12.8,
                          ),
                          logoAlign: NLogoAlign.leftBottom,
                          logoMargin: _logoMargin,
                        ),
                        onMapReady: _onMapReady,
                        onCameraChange: (_, _) {
                          if (_cameraIdle) setState(() => _cameraIdle = false);
                        },
                        onCameraIdle: () => setState(() => _cameraIdle = true),
                      ),
                      if (_covered)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black87,
                            child: Center(
                              child: Text(
                                '지도 가림',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LabeledSwitch(
                        label: 'SDK 오버레이',
                        value: _overlaysOn,
                        onChanged: _controller == null ? null : _setOverlays,
                      ),
                      _LabeledSwitch(
                        label: '지도 가리기',
                        value: _covered,
                        onChanged: (v) => setState(() => _covered = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _run(_pickPhotos),
                          child: Text('사진 (${_photos.length})'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _ready ? () => _run(_snapshot) : null,
                          child: const Text('스냅샷'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _ready ? () => _run(_compose) : null,
                          child: const Text('합성'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledSwitch extends StatelessWidget {
  const _LabeledSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ResultScreen extends StatelessWidget {
  const _ResultScreen({
    required this.title,
    required this.bytes,
    required this.info,
  });

  final String title;
  final Uint8List bytes;
  final List<String> info;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 8,
              child: Center(child: Image.memory(bytes)),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(12),
            child: SafeArea(
              top: false,
              child: SelectableText(
                info.join('\n'),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

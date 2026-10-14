import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'route_composer.dart';
import 'route_geometry.dart';
import 'sample_route.dart';

/// 0단계 이미지 내보내기 검증 화면.
///
/// - 스냅샷: 지도 스냅샷만 찍어 형식과 해상도를 본다.
/// - SDK 오버레이: 켜고 스냅샷을 찍으면 SDK가 그린 마커·선이 이미지에 들어가는지 본다.
/// - 합성: 스냅샷 위에 Flutter Canvas로 동선을 그려 PNG로 저장한다.
class SnapshotLabScreen extends StatefulWidget {
  const SnapshotLabScreen({super.key});

  @override
  State<SnapshotLabScreen> createState() => _SnapshotLabScreenState();
}

class _SnapshotLabScreenState extends State<SnapshotLabScreen> {
  NaverMapController? _controller;
  Size? _mapSize;
  bool _overlaysOn = true;
  bool _cameraIdle = false;
  bool _busy = false;

  bool get _ready => _controller != null && _cameraIdle && !_busy;

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

  String get _overlayInfo => 'SDK 오버레이: ${_overlaysOn ? "켜짐" : "꺼짐"}';

  Future<void> _snapshot() async {
    final (bytes, image, ms) = await _takeSnapshot();
    _openResult('스냅샷', bytes, [
      '형식: ${detectImageFormat(bytes)}',
      '이미지: ${image.width} x ${image.height} px',
      ..._screenInfo(),
      '용량: ${_kb(bytes.length)}',
      '소요: $ms ms',
      _overlayInfo,
    ]);
  }

  Future<void> _compose() async {
    final watch = Stopwatch()..start();
    final (_, base, snapshotMs) = await _takeSnapshot();
    final scale = base.width / _mapSize!.width;
    final points = <Offset>[];
    for (final stop in sampleStops) {
      final p = await _controller!.latLngToScreenLocation(stop.position);
      points.add(Offset(p.x * scale, p.y * scale));
    }
    final composed = await composeRoute(
      base: base,
      points: points,
      names: sampleStops.map((s) => s.name).toList(),
      title: sampleTitle,
      scale: scale,
    );
    final png = (await composed.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final file = File(
      '${Directory.systemTemp.path}/route_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(png);

    _openResult('합성', png, [
      '형식: ${detectImageFormat(png)}',
      '이미지: ${composed.width} x ${composed.height} px',
      ..._screenInfo(),
      '배율(이미지 px / 논리 px): ${scale.toStringAsFixed(3)}',
      '용량: ${_kb(png.length)}',
      '소요: 스냅샷 $snapshotMs ms / 전체 ${watch.elapsedMilliseconds} ms',
      '$_overlayInfo (켜져 있으면 빨간 직선과 파란 곡선의 끝점이 겹쳐야 정상)',
      '저장: ${file.path}',
    ]);
  }

  List<String> _screenInfo() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = _mapSize!;
    return [
      '지도 위젯: ${size.width.toStringAsFixed(0)} x ${size.height.toStringAsFixed(0)} 논리 px',
      '기기 픽셀 비율: $dpr → 실제 ${(size.width * dpr).round()} x ${(size.height * dpr).round()} px',
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _mapSize = constraints.biggest;
                return NaverMap(
                  options: const NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(37.5669, 126.9826),
                      zoom: 12.8,
                    ),
                  ),
                  onMapReady: (controller) {
                    _controller = controller;
                    _setOverlays(_overlaysOn);
                  },
                  onCameraChange: (_, _) {
                    if (_cameraIdle) setState(() => _cameraIdle = false);
                  },
                  onCameraIdle: () => setState(() => _cameraIdle = true),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Text('SDK 오버레이'),
                  Switch(
                    value: _overlaysOn,
                    onChanged: _controller == null ? null : _setOverlays,
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _ready ? () => _run(_snapshot) : null,
                    child: const Text('스냅샷'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _ready ? () => _run(_compose) : null,
                    child: const Text('합성'),
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

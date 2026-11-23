import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/map/map_provider.dart';
import '../../core/map/map_registry.dart';
import '../../core/share/image_sharing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/today.dart';
import '../../data/models/map_provider_type.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_route.dart';
import '../../data/photos/photo_images.dart';
import '../../data/trips/trip_repository.dart';
import '../../l10n/l10n.dart';
import 'export_scene.dart';
import 'widgets/export_canvas.dart';

/// 내보낼 여행.
final exportTripProvider = StreamProvider.autoDispose.family<Trip?, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).watchTrip(tripId),
);

/// 내보낼 여행의 동선. 늘 최신 데이터로 그린다(이미지를 저장해 두지 않는다).
final exportRouteProvider = StreamProvider.autoDispose
    .family<TripRoute, String>(
      (ref, tripId) => ref.watch(tripRepositoryProvider).watchRoute(tripId),
    );

/// 이미지 만들기. 미리보기에서 범위와 넣을 것을 바꿔 보고 사진첩에 저장하거나 공유한다.
///
/// - 미리보기는 저장할 이미지 그대로다. 결과 크기([exportPixelSize])의 지도를 띄워 찍고, 그 위에 동선을 그린
///   [ExportCanvas]를 줄여 보여 준다. 지도는 미리보기 뒤에 가려져 있다(가려져도 찍힌다).
/// - 범위, 숙소, 제목, (여행 후의) 사진을 바꾸면 지도를 다시 맞춰 찍는다. 그동안 앞의 미리보기를 흐리게 둔다.
/// - [initialDay]와 [initialLodging]은 동선 화면에서 보던 일차와 숙소 켜짐이다.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({
    super.key,
    required this.tripId,
    this.initialDay,
    this.initialLodging = true,
  });

  final String tripId;
  final int? initialDay;
  final bool initialLodging;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late ExportOptions _options = ExportOptions(
    day: widget.initialDay,
    lodging: widget.initialLodging,
  );

  MapCapture? _capture;
  bool _mapFailed = false;

  /// 마지막으로 다 그린 미리보기. 지도를 다시 찍는 동안 흐리게 보여 준다.
  (MapCapture, ExportScene)? _shown;

  final _canvasKey = GlobalKey();
  final _shareKey = GlobalKey();

  /// 사진을 받아 두는 중이거나 받은 결과(받았으면 true). 저장하기 전에 모두 기다린다.
  final _photoLoads = <ImageProvider, Future<bool>>{};
  final _failedPhotos = <ImageProvider>{};

  /// 저장이나 공유 중이다. 그동안 두 버튼을 잠근다.
  bool _working = false;

  void _setOptions(ExportOptions options) => setState(() => _options = options);

  void _onCaptured(MapCapture capture) {
    if (!mounted) return;
    setState(() {
      _capture = capture;
      _mapFailed = false;
    });
  }

  void _onMapFailed() {
    if (mounted) setState(() => _mapFailed = true);
  }

  /// 사진 마커의 사진을 먼저 받는다. 받지 못한 사진은 사진 없는 원 마커로 그린다(앱 지도와 같다).
  void _precache(ExportScene scene) {
    for (final marker in scene.markers) {
      final photo = marker.look.photo;
      if (photo == null || _photoLoads.containsKey(photo)) continue;
      final done = Completer<bool>();
      _photoLoads[photo] = done.future;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return done.complete(false);
        var failed = false;
        await precacheImage(photo, context, onError: (_, _) => failed = true);
        if (failed && mounted) setState(() => _failedPhotos.add(photo));
        done.complete(!failed);
      });
    }
  }

  ExportScene _withoutFailedPhotos(ExportScene scene) {
    if (_failedPhotos.isEmpty) return scene;
    return ExportScene(
      markers: [
        for (final marker in scene.markers)
          _failedPhotos.contains(marker.look.photo)
              ? marker.withLook(marker.look.withoutPhoto())
              : marker,
      ],
      lines: scene.lines,
      arrows: scene.arrows,
      lineIcons: scene.lineIcons,
      title: scene.title,
      subtitle: scene.subtitle,
      legendDays: scene.legendDays,
      hasPhotos: scene.hasPhotos,
      bounds: scene.bounds,
    );
  }

  /// 미리보기를 결과 크기의 PNG로 만든다.
  Future<Uint8List?> _render() async {
    final loaded = await Future.wait(_photoLoads.values);
    // 받지 못한 사진이 있으면 원 마커로 바꾼 화면이 그려진 뒤에 찍는다.
    if (loaded.contains(false)) await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(
      pixelRatio: exportPixelSize.width / boundary.size.width,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// 확장자 없는 파일 이름. 예: MapMarker_20261020_143005.
  String _fileName() {
    final now = ref.read(clockProvider)();
    return 'MapMarker_${DateFormat('yyyyMMdd_HHmmss').format(now)}';
  }

  Future<void> _run(Future<void> Function(Uint8List png) task) async {
    setState(() => _working = true);
    try {
      final png = await _render();
      if (png != null && mounted) await task(png);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() => _run((png) async {
    final sharing = ref.read(imageSharingProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final result = await sharing.saveToGallery(png, name: _fileName());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(switch (result) {
        GallerySaveResult.saved => SnackBar(content: Text(l10n.exportSaved)),
        GallerySaveResult.denied => SnackBar(
          content: Text(l10n.exportSaveDenied),
          action: SnackBarAction(
            label: l10n.exportSettings,
            onPressed: sharing.openAppSettings,
          ),
        ),
        GallerySaveResult.failed => SnackBar(
          content: Text(l10n.exportSaveFailed),
        ),
      });
  });

  Future<void> _share() => _run((png) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await ref
          .read(imageSharingProvider)
          .share(png, name: _fileName(), origin: origin);
    } on Object catch (error) {
      debugPrint('공유하지 못했습니다: $error');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.exportShareFailed)));
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trip = ref.watch(exportTripProvider(widget.tripId));
    final route = ref.watch(exportRouteProvider(widget.tripId));
    final message = switch ((trip, route)) {
      (AsyncError(), _) || (_, AsyncError()) => l10n.tripLoadFailed,
      (AsyncData(value: null), _) => l10n.tripNotFound,
      _ => null,
    };
    final body = switch ((trip.value, route.value)) {
      _ when message != null => Center(child: Text(message)),
      (final trip?, final route?) => _buildBody(context, trip, route),
      _ => const Center(child: CircularProgressIndicator()),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportOpen)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context, Trip trip, TripRoute route) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final days = trip.nights + 1;
    // 여행 기간이 줄어 고른 일차가 없어졌으면 전체로 돌아간다.
    final options = (_options.day ?? 0) > days
        ? _options.copyWith(day: () => null)
        : _options;
    final scene = _withoutFailedPhotos(
      buildExportScene(
        trip: trip,
        route: route,
        phase: trip.phaseOn(ref.watch(todayProvider)),
        options: options,
        colors: context.appColors,
        l10n: l10n,
        photoOf: ref.watch(photoImagesProvider).thumbnailOf,
      ),
    );
    _precache(scene);
    final size = exportPixelSize / MediaQuery.devicePixelRatioOf(context);
    final metrics = ExportMetrics(context, size);
    final frame = scene.frameFor(
      titleBottom: metrics.titleCardRect(scene)?.bottom,
    );
    final capture = _capture;
    if (frame != null && capture != null && capture.frame == frame) {
      _shown = (capture, scene);
    }
    final shown = _shown;
    final ready = frame != null && capture?.frame == frame && !_mapFailed;
    final map = ref.watch(
      mapProviderProvider(trip.mapProvider ?? MapProviderType.naver),
    );
    final hasLodging = route
        .view(day: options.day)
        .stops
        .any((stop) => stop.isLodging);

    final notice = frame == null
        ? l10n.exportRangeEmpty
        : _mapFailed
        ? l10n.exportMapFailed
        : null;

    final preview = AspectRatio(
      aspectRatio: exportPixelSize.aspectRatio,
      child: ClipRRect(
        borderRadius: AppRadius.md,
        child: FittedBox(
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              children: [
                if (frame != null)
                  Positioned.fill(
                    child: map.buildCaptureMap(
                      frame: frame,
                      onCaptured: _onCaptured,
                      onFailed: _onMapFailed,
                    ),
                  ),
                // 지도는 찍으려고 띄운 것이라 보이지 않게 덮는다.
                Positioned.fill(
                  child: ColoredBox(color: scheme.surfaceContainerHighest),
                ),
                if (shown != null && notice == null)
                  RepaintBoundary(
                    key: _canvasKey,
                    child: ExportCanvas(
                      capture: shown.$1,
                      scene: shown.$2,
                      metrics: metrics,
                    ),
                  ),
                if (notice == null && !ready)
                  Positioned.fill(
                    child: ColoredBox(
                      color: scheme.surface.withValues(
                        alpha: 1 - AppOpacity.backdrop,
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (notice != null)
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: Text(notice, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final insets = MediaQuery.paddingOf(context);
    final side = EdgeInsets.only(
      left: insets.left + AppSpace.lg,
      right: insets.right + AppSpace.lg,
    );
    final canExport = ready && notice == null && !_working;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: side + const EdgeInsets.only(top: AppSpace.sm),
            child: Center(child: preview),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: side,
          child: Row(
            children: [
              for (final day in <int?>[null, for (var d = 1; d <= days; d++) d])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.sm),
                  child: ChoiceChip(
                    label: Text(
                      day == null ? l10n.routeAllDays : l10n.routeDay(day),
                    ),
                    selected: options.day == day,
                    onSelected: (_) =>
                        _setOptions(options.copyWith(day: () => day)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Padding(
          padding: side,
          child: Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              if (scene.hasPhotos)
                FilterChip(
                  label: Text(l10n.exportPhotos),
                  selected: options.photos,
                  onSelected: (on) => _setOptions(options.copyWith(photos: on)),
                ),
              if (hasLodging)
                FilterChip(
                  label: Text(l10n.exportLodging),
                  selected: options.lodging,
                  onSelected: (on) =>
                      _setOptions(options.copyWith(lodging: on)),
                ),
              FilterChip(
                label: Text(l10n.exportTitle),
                selected: options.title,
                onSelected: (on) => _setOptions(options.copyWith(title: on)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Padding(
          padding: side + EdgeInsets.only(bottom: insets.bottom + AppSpace.md),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canExport ? _save : null,
                  child: Text(l10n.exportSave),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: FilledButton.icon(
                  key: _shareKey,
                  onPressed: canExport ? _share : null,
                  icon: const Icon(Icons.share),
                  label: Text(l10n.exportShare),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/map/geo.dart';
import '../../core/map/map_provider.dart';
import '../../core/map/map_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/today.dart';
import '../../data/models/map_provider_type.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_route.dart';
import '../../l10n/l10n.dart';
import 'route_scene.dart';
import 'trip_detail_controller.dart';
import 'widgets/rename_trip_dialog.dart';
import 'widgets/route_day_chips.dart';
import 'widgets/route_title_bar.dart';
import 'widgets/size_reporter.dart';

/// 여행 동선 페이지. 지도에 장소와 구간을 보여 주고, 여행 전체와 일차별 보기를 오간다.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(tripDetailProvider(tripId))) {
      AsyncData(value: final trip?) => _TripRoutePage(trip: trip),
      AsyncData() => _Message(l10n.tripNotFound),
      AsyncError() => _Message(l10n.tripLoadFailed),
      AsyncLoading() => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// 지도는 시스템 막대 뒤까지 화면 전체에 그린다.
/// 그 위에 뜨는 제목 카드·일차 칩·버튼과 지도 로고는 시스템 여백만큼 띄운다.
class _TripRoutePage extends ConsumerStatefulWidget {
  const _TripRoutePage({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_TripRoutePage> createState() => _TripRoutePageState();
}

class _TripRoutePageState extends ConsumerState<_TripRoutePage> {
  /// 위에 뜬 제목 카드와 일차 칩의 화면 위쪽부터의 높이. 재기 전에는 지도를 띄우지 않는다.
  /// 지도를 만들 때부터 여백이 맞아야 처음 카메라가 제목 카드 밑으로 숨지 않는다.
  double? _overlayHeight;

  Trip get trip => widget.trip;

  Future<void> _rename() async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => RenameTripDialog(
        title: trip.title,
        defaultTitle: context.l10n.defaultTitleOf(trip),
      ),
    );
    if (title == null || !mounted) return;
    await ref.read(tripDetailProvider(trip.id).notifier).rename(title);
  }

  void _onOverlaySize(Size size) {
    if (mounted && size.height != _overlayHeight) {
      setState(() => _overlayHeight = size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final insets = MediaQuery.paddingOf(context);
    final choice = ref.watch(routeChoiceProvider(trip.id));
    final choices = ref.read(routeChoiceProvider(trip.id).notifier);
    final route = ref.watch(tripRouteProvider(trip.id));
    final view = route.value?.view(
      day: choice.day,
      showLodging: choice.showLodging,
    );
    final overlayHeight = _overlayHeight;

    return Scaffold(
      body: Stack(
        children: [
          if (route case AsyncData(
            value: final route,
          ) when view != null && overlayHeight != null)
            Positioned.fill(
              child: _RouteMap(
                trip: trip,
                route: route,
                view: view,
                cameraKey: choice.fitCount,
                padding: insets.copyWith(top: overlayHeight),
              ),
            ),
          if (overlayHeight != null)
            if (_messageOf(route, view, choice) case final message?)
              Positioned.fill(
                top: overlayHeight,
                child: Center(child: _MessageCard(message)),
              ),
          if (view != null && view.stops.isNotEmpty)
            Positioned(
              right: insets.right + AppSpace.lg,
              bottom: insets.bottom + AppSpace.lg,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: l10n.routeFitTooltip,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLowest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                onPressed: choices.fitCamera,
                child: const Icon(Icons.fit_screen_outlined),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // 앱 바가 없어서 상태 표시줄 아이콘 색을 직접 정한다. 지도 바탕이 밝아서 어둡게 둔다.
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              child: SizeReporter(
                onSize: _onOverlaySize,
                child: _TopOverlay(
                  trip: trip,
                  choice: choice,
                  onRename: _rename,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _messageOf(
    AsyncValue<TripRoute> route,
    RouteView? view,
    RouteChoice choice,
  ) {
    final l10n = context.l10n;
    return switch (route) {
      AsyncError() => l10n.tripLoadFailed,
      AsyncData(value: final route) when route.stops.isEmpty => l10n.routeEmpty,
      _ when view == null || view.stops.isNotEmpty => null,
      _ => switch (choice.day) {
        final day? => l10n.routeDayEmpty(day),
        null => l10n.routeNothingVisible,
      },
    };
  }
}

/// 위에 뜨는 제목 카드와 일차 칩.
class _TopOverlay extends ConsumerWidget {
  const _TopOverlay({
    required this.trip,
    required this.choice,
    required this.onRename,
  });

  final Trip trip;
  final RouteChoice choice;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final insets = MediaQuery.paddingOf(context);
    final today = ref.watch(todayProvider);
    final choices = ref.read(routeChoiceProvider(trip.id).notifier);
    final side = EdgeInsets.only(
      left: insets.left + AppSpace.md,
      right: insets.right + AppSpace.md,
    );
    return Padding(
      padding: EdgeInsets.only(top: insets.top + AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: side,
            child: RouteTitleBar(
              title: trip.title,
              subtitle: l10n.tripRouteSubtitle(
                l10n.tripPhaseName(trip.phaseOn(today)),
                l10n.tripSummaryOf(trip),
              ),
              onRename: onRename,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          RouteDayChips(
            days: trip.nights + 1,
            selectedDay: choice.day,
            showLodging: choice.showLodging,
            onDaySelected: choices.selectDay,
            onShowLodgingChanged: choices.setShowLodging,
            padding: side,
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }
}

class _RouteMap extends ConsumerWidget {
  const _RouteMap({
    required this.trip,
    required this.route,
    required this.view,
    required this.cameraKey,
    required this.padding,
  });

  final Trip trip;
  final TripRoute route;
  final RouteView view;
  final Object cameraKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 지도는 여행 단위로 정한다. 1단계는 네이버만 쓰고, 장소 위치로 고르는 것은 2단계다.
    final map = ref.watch(
      mapProviderProvider(trip.mapProvider ?? MapProviderType.naver),
    );
    final (:markers, :lines) = routeOverlays(
      route: route,
      view: view,
      colors: context.appColors,
    );
    return map.buildMap(
      MapScene(
        markers: markers,
        lines: lines,
        camera: MapCameraRequest(
          key: cameraKey,
          bounds: cameraBoundsFor(view.stops.map((stop) => stop.position)),
        ),
        padding: padding,
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(text)),
    );
  }
}

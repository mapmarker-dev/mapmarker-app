import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/links/open_link.dart';
import '../../core/map/external_map.dart';
import '../../core/map/geo.dart';
import '../../core/map/map_provider.dart';
import '../../core/map/map_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/today.dart';
import '../../data/models/map_provider_type.dart';
import '../../data/models/stop.dart';
import '../../data/models/trip.dart';
import '../../data/models/trip_route.dart';
import '../../l10n/l10n.dart';
import '../../data/models/new_id.dart';
import 'day_itinerary.dart';
import 'route_scene.dart';
import 'stop_draft.dart';
import 'stop_placement.dart';
import 'trip_detail_controller.dart';
import 'widgets/rename_trip_dialog.dart';
import 'route_sheet_layout.dart';
import 'widgets/day_itinerary_list.dart';
import 'widgets/route_day_chips.dart';
import 'widgets/route_day_panel.dart';
import 'widgets/route_day_sheet.dart';
import 'widgets/route_title_bar.dart';
import 'widgets/stop_form_dialog.dart';
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
/// 그 위에 뜨는 제목 카드·일차 칩·버튼·시트와 지도 로고는 시스템 여백만큼 띄운다.
///
/// 일차 보기에서는 아래에 일차 동선 시트가 뜬다. 지도 여백에는 접힌 시트 높이까지만 넣고,
/// 시트를 더 올리면 로고만 올린다(카메라와 지도 내용은 그대로).
class _TripRoutePage extends ConsumerStatefulWidget {
  const _TripRoutePage({required this.trip});

  final Trip trip;

  @override
  ConsumerState<_TripRoutePage> createState() => _TripRoutePageState();
}

/// 시트 제목 줄 높이를 재기 전에 쓰는 어림값.
const _estimatedSheetHeader = 56.0;

/// Material 작은 플로팅 버튼(맞추기 버튼)의 크기.
const _smallFabSize = 40.0;

class _TripRoutePageState extends ConsumerState<_TripRoutePage> {
  /// 위에 뜬 제목 카드와 일차 칩의 화면 위쪽부터의 높이. 재기 전에는 지도를 띄우지 않는다.
  /// 지도를 만들 때부터 여백이 맞아야 처음 카메라가 제목 카드 밑으로 숨지 않는다.
  double? _overlayHeight;

  final _sheetController = DraggableScrollableController();
  final _sheetKey = GlobalKey<RouteDaySheetState>();

  /// 시트 제목 줄 높이. 일차마다 같아서 한 번 재면 계속 쓴다.
  double _sheetHeaderHeight = _estimatedSheetHeader;

  /// 시트가 접힌 높이보다 더 올라온 높이. 로고를 이만큼 더 올린다.
  double _sheetLift = 0;

  /// 장소를 넣으려고 누른 자리. 지도에 임시 핀을 꽂고, 아래 카드에서 추가하거나 취소한다.
  MapTap? _draftPlace;

  /// 일차 동선 목록에서 펼친 줄과 고른 줄. 기기를 돌려 아래 시트와 오른쪽 패널이 바뀌어도 남는다.
  final _selection = ItinerarySelection();

  /// 지난번에 그린 목록 자리. 기기를 돌려 바뀐 것을 알아챈다.
  RouteSheetLayout? _layout;

  Trip get trip => widget.trip;

  RouteChoiceController get _choices =>
      ref.read(routeChoiceProvider(trip.id).notifier);

  @override
  void dispose() {
    _sheetController.dispose();
    _selection.dispose();
    super.dispose();
  }

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

  void _onSheetHeaderSize(double height) {
    if (mounted && height != _sheetHeaderHeight) {
      setState(() => _sheetHeaderHeight = height);
    }
  }

  void _onSheetLift(double lift) {
    if (mounted && (lift - _sheetLift).abs() >= 1) {
      setState(() => _sheetLift = lift);
    }
  }

  /// 마커를 누르면 시트에서 그 자리의 장소를 보여 준다.
  /// 전체 보기에서는 그 일차로 들어간다. 같은 자리의 장소가 여러 일차에 있으면 일차를 고르게 한다.
  Future<void> _onMarkerTap(
    TripRoute route,
    RouteView view,
    int? day,
    String markerId,
  ) async {
    if (markerId == draftMarkerId) return _addStop(route, day);
    final stops = stopsAtMarker(view, markerId);
    if (stops.isEmpty) return;
    if (day != null) {
      _choices.focusOn([for (final stop in stops) stop.id]);
      return;
    }
    final days = {for (final stop in stops) stop.day}.toList()..sort();
    final chosen = days.length == 1 ? days.single : await _chooseDay(days);
    if (chosen == null || !mounted) return;
    _choices.selectDay(
      chosen,
      focus: [
        for (final stop in stops)
          if (stop.day == chosen) stop.id,
      ],
    );
  }

  Future<int?> _chooseDay(List<int> days) => showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.routeChooseDay),
      children: [
        for (final day in days)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(day),
            child: Text(context.l10n.routeDay(day)),
          ),
      ],
    ),
  );

  /// 선을 누르면 시트에서 그 구간을 보여 준다.
  /// 전체 보기에서는 선 색의 일차(도착 장소의 일차)로 들어간다.
  void _onLineTap(TripRoute route, int? day, String segmentId) {
    final segment = route.segments.where((s) => s.id == segmentId).firstOrNull;
    final to = segment == null ? null : route.stopById(segment.toStopId);
    if (to == null) return;
    if (day != null) {
      _choices.focusOn([segmentId]);
    } else {
      _choices.selectDay(to.day, focus: [segmentId]);
    }
  }

  /// 지도 빈 곳(또는 지도에 원래 있는 장소 이름)을 누르면 그 자리에 임시 핀을 꽂는다.
  /// 아래 시트가 올라와 있으면 시트만 접는다.
  /// 오른쪽 패널은 지도를 덮지 않아서 접을 것이 없다.
  void _onMapTap(MapTap tap, int? day) {
    if (_layout == RouteSheetLayout.bottom && day != null && _sheetLift > 0) {
      _sheetKey.currentState?.collapse();
      return;
    }
    setState(() => _draftPlace = tap);
  }

  /// 지금 저장소에 있는 동선. 입력 화면을 닫는 사이에 바뀌었을 수 있어서 넣기 직전에 다시 읽는다.
  TripRoute _latestRoute(TripRoute fallback) =>
      ref.read(tripRouteProvider(trip.id)).value ?? fallback;

  static List<Stop> _stopsOfDay(TripRoute route, int day) => [
    for (final stop in route.stops)
      if (stop.day == day) stop,
  ];

  /// 임시 핀 자리에 장소를 넣는다. 입력 화면에서 이름 등을 받는다.
  Future<void> _addStop(TripRoute route, int? viewDay) async {
    final place = _draftPlace;
    if (place == null) return;
    final draft = await showStopForm(
      context,
      trip: trip,
      isNew: true,
      initial: StopDraft(
        name: place.placeName ?? '',
        day: defaultDayForNewStop(route, viewDay: viewDay),
      ),
    );
    if (draft == null || !mounted) return;
    final latest = _latestRoute(route);
    final stop = draft.toNewStop(
      id: newId(),
      tripId: trip.id,
      position: place.position,
      order: insertionOrder(_stopsOfDay(latest, draft.day), draft.kind),
    );
    await ref.read(tripDetailProvider(trip.id).notifier).addStop(stop);
    if (!mounted) return;
    setState(() => _draftPlace = null);
    _showPlaced(stop.id, stop.day, moved: false);
  }

  Future<void> _editStop(TripRoute route, Stop stop) async {
    final initial = StopDraft.of(stop);
    final draft = await showStopForm(
      context,
      trip: trip,
      isNew: false,
      initial: initial,
    );
    if (draft == null || draft == initial || !mounted) return;
    final controller = ref.read(tripDetailProvider(trip.id).notifier);
    await controller.updateStop(draft.applyTo(stop));
    if (draft.day == stop.day || !mounted) return;
    // 다른 일차로 옮기면 새 장소를 넣을 때와 같은 자리(맨 뒤, 밤 숙소 앞)에 넣는다.
    final others = [
      for (final s in _stopsOfDay(_latestRoute(route), draft.day))
        if (s.id != stop.id) s,
    ];
    await controller.moveStop(
      stop.id,
      day: draft.day,
      order: insertionOrder(others, draft.kind),
    );
    if (mounted) _showPlaced(stop.id, draft.day, moved: true);
  }

  /// 연박: 전날 밤 숙소를 [day]일차 밤 숙소로 그 일차 맨 뒤에 넣는다.
  Future<void> _stayAgain(TripRoute route, int day, Stop lodging) async {
    final stop = stayAnotherNight(
      lodging,
      id: newId(),
      day: day,
      order: _stopsOfDay(_latestRoute(route), day).length,
    );
    await ref.read(tripDetailProvider(trip.id).notifier).addStop(stop);
    if (mounted) _choices.focusOn([stop.id]);
  }

  /// 넣거나 옮긴 장소를 보여 준다. 카메라는 움직이지 않는다.
  /// 일차 보기에서 그 일차면 시트에서 그 줄을 보여 주고, 다른 일차면 어디로 갔는지 알린다.
  void _showPlaced(String stopId, int stopDay, {required bool moved}) {
    final viewDay = ref.read(routeChoiceProvider(trip.id)).day;
    if (viewDay == null) return;
    if (viewDay == stopDay) {
      _choices.focusOn([stopId]);
      return;
    }
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          moved ? l10n.stopMovedToDay(stopDay) : l10n.stopAddedToDay(stopDay),
        ),
      ),
    );
  }

  Future<void> _openMap(Stop stop) async {
    final opened = await ref.read(openLinkProvider)(
      naverMapSearchUri(stop.name, stop.position),
    );
    if (opened || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.itineraryOpenFailed)));
  }

  Future<void> _confirmDelete(Stop stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.deleteStopTitle(stop.name)),
          content: Text(l10n.deleteStopMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.deleteStop),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await ref.read(tripDetailProvider(trip.id).notifier).deleteStop(stop.id);
  }

  void _reorder(
    TripRoute route,
    int day,
    List<String> visibleIds,
    int oldIndex,
    int newIndex,
  ) {
    // 제자리에 놓았다.
    if (newIndex == oldIndex) return;
    final order = reorderedStopOrder(
      visibleIds: visibleIds,
      dayStops: [
        for (final stop in route.stops)
          if (stop.day == day) stop,
      ],
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    ref
        .read(tripDetailProvider(trip.id).notifier)
        .moveStop(visibleIds[oldIndex], day: day, order: order);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final insets = MediaQuery.paddingOf(context);
    final choice = ref.watch(routeChoiceProvider(trip.id));
    ref.listen(routeChoiceProvider(trip.id).select((c) => c.day), (_, day) {
      // 전체 보기로 나가면 시트가 사라진다. 다시 들어오면 접힌 시트로 시작한다.
      if (day == null) _sheetLift = 0;
      // 다른 보기로 가면 꽂아 둔 임시 핀은 버린다.
      if (_draftPlace != null) setState(() => _draftPlace = null);
    });
    final route = ref.watch(tripRouteProvider(trip.id));
    final view = route.value?.view(
      day: choice.day,
      showLodging: choice.showLodging,
    );
    final overlayHeight = _overlayHeight;
    final day = choice.day;
    final itinerary = switch (route) {
      AsyncData(value: final route) when view != null && day != null =>
        DayItinerary.of(route, view, day),
      _ => null,
    };
    final screen = MediaQuery.sizeOf(context);
    final layout = routeSheetLayoutOf(screen);
    final isSide = layout == RouteSheetLayout.side;
    if (_layout != null && _layout != layout) _onLayoutChanged(layout, choice);
    _layout = layout;
    // 오른쪽 패널을 열면 지도 영역은 패널 왼쪽까지다.
    final panelWidth = sidePanelWidth(screen.width);
    final panelShown = isSide && itinerary != null && choice.panelOpen;
    final right = panelShown ? panelWidth + insets.right : insets.right;
    // 아래 시트가 있으면 지도와 버튼은 접힌 시트 위에 둔다.
    final bottom = itinerary == null || isSide
        ? insets.bottom
        : insets.bottom + _sheetHeaderHeight;

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
                padding: insets.copyWith(
                  top: overlayHeight,
                  right: right,
                  bottom: bottom,
                ),
                // 로고는 왼쪽 아래라서 오른쪽 패널에는 가리지 않는다.
                logoLift: itinerary == null || isSide ? 0 : _sheetLift,
                draft: _draftPlace,
                onMarkerTap: (id) => _onMarkerTap(route, view, day, id),
                onLineTap: (id) => _onLineTap(route, day, id),
                onMapTap: (tap) => _onMapTap(tap, day),
              ),
            ),
          if (overlayHeight != null)
            if (_messageOf(route, view, choice) case final message?)
              Positioned.fill(
                top: overlayHeight,
                right: right - insets.right,
                bottom: bottom,
                child: Center(child: _MessageCard(message)),
              ),
          if (view != null && view.stops.isNotEmpty)
            Positioned(
              right: right + AppSpace.lg,
              bottom: bottom + AppSpace.lg,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: l10n.routeFitTooltip,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLowest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                onPressed: _choices.fitCamera,
                child: const Icon(Icons.fit_screen_outlined),
              ),
            ),
          if (route case AsyncData(value: final route))
            if (_draftPlace case final place?)
              Positioned(
                left: insets.left + AppSpace.md,
                // 오른쪽의 맞추기 버튼을 가리지 않는다.
                right: right + AppSpace.lg + _smallFabSize + AppSpace.sm,
                bottom: bottom + AppSpace.lg,
                child: _DraftCard(
                  place: place,
                  onAdd: () => _addStop(route, day),
                  onCancel: () => setState(() => _draftPlace = null),
                ),
              ),
          if (route case AsyncData(
            value: final route,
          ) when itinerary != null && overlayHeight != null)
            if (isSide)
              // 닫혀도 그려 둔다. 다시 열 때 넘긴 자리와 펼친 줄이 그대로다.
              AnimatedPositioned(
                duration: _panelDuration,
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                width: panelWidth + insets.right,
                right: choice.panelOpen ? 0 : -(panelWidth + insets.right),
                child: RouteDayPanel(
                  header: ItineraryHeader(
                    trip: trip,
                    itinerary: itinerary,
                    onClose: _choices.closePanel,
                  ),
                  list: _itineraryList(
                    route,
                    itinerary,
                    choice,
                    padding: EdgeInsets.only(bottom: insets.bottom),
                    // 패널은 일차를 고르거나 지도를 누를 때 이미 열린다.
                    onReveal: () async {},
                  ),
                ),
              )
            else
              Positioned.fill(
                top: overlayHeight,
                child: RouteDaySheet(
                  key: _sheetKey,
                  controller: _sheetController,
                  headerHeight: _sheetHeaderHeight,
                  header: ItineraryHeader(
                    trip: trip,
                    itinerary: itinerary,
                    showHandle: true,
                  ),
                  list: _itineraryList(
                    route,
                    itinerary,
                    choice,
                    padding: insets.copyWith(top: 0),
                    onReveal: () async => _sheetKey.currentState?.reveal(),
                  ),
                  onHeaderSize: _onSheetHeaderSize,
                  onLift: _onSheetLift,
                ),
              ),
          Positioned(
            top: 0,
            left: 0,
            // 오른쪽 패널을 열면 제목 카드와 일차 칩은 지도 영역 안에 둔다.
            right: panelShown ? right : 0,
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
                  // 패널이 오른쪽 시스템 여백을 덮으면 따로 띄울 필요가 없다.
                  rightInset: panelShown ? 0 : insets.right,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _panelDuration = Duration(milliseconds: 250);

  /// 그날의 목록. 아래 시트와 오른쪽 패널이 같은 목록과 같은 고른 줄([_selection])을 쓴다.
  Widget _itineraryList(
    TripRoute route,
    DayItinerary itinerary,
    RouteChoice choice, {
    required EdgeInsets padding,
    required Future<void> Function() onReveal,
  }) => DayItineraryList(
    route: route,
    itinerary: itinerary,
    selection: _selection,
    focus: choice.focus,
    focusCount: choice.focusCount,
    onReveal: onReveal,
    padding: padding,
    onOpenMap: _openMap,
    onDelete: _confirmDelete,
    onEdit: (stop) => _editStop(route, stop),
    onStayAgain: (lodging) => _stayAgain(route, itinerary.day, lodging),
    onReorder: (visibleIds, oldIndex, newIndex) =>
        _reorder(route, itinerary.day, visibleIds, oldIndex, newIndex),
  );

  /// 기기를 돌려 목록 자리가 바뀌었다. 펼친 줄과 고른 줄은 [_selection]에 남아 있다.
  ///
  /// 가로→세로: 오른쪽 패널이 열려 있었으면 아래 시트를 가운데 높이(40%)로 올린다.
  /// 세로→가로: 패널은 [RouteChoice.panelOpen]대로다(일차를 고르면 열린다).
  /// 아래 시트의 올라온 높이는 새 시트가 알려 줄 때까지 0으로 둔다.
  void _onLayoutChanged(RouteSheetLayout layout, RouteChoice choice) {
    _sheetLift = 0;
    if (layout == RouteSheetLayout.bottom &&
        choice.day != null &&
        choice.panelOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sheetKey.currentState?.reveal();
      });
    }
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
    required this.rightInset,
  });

  final Trip trip;
  final RouteChoice choice;
  final VoidCallback onRename;

  /// 오른쪽에서 비킬 시스템 여백. 오른쪽 패널이 열려 있으면 패널이 덮어서 0이다.
  final double rightInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final insets = MediaQuery.paddingOf(context);
    final today = ref.watch(todayProvider);
    final choices = ref.read(routeChoiceProvider(trip.id).notifier);
    final side = EdgeInsets.only(
      left: insets.left + AppSpace.md,
      right: rightInset + AppSpace.md,
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
    required this.logoLift,
    required this.draft,
    required this.onMarkerTap,
    required this.onLineTap,
    required this.onMapTap,
  });

  final Trip trip;
  final TripRoute route;
  final RouteView view;
  final Object cameraKey;
  final EdgeInsets padding;
  final double logoLift;

  /// 임시 핀 자리. 카메라 맞춤에는 넣지 않는다.
  final MapTap? draft;
  final ValueChanged<String> onMarkerTap;
  final ValueChanged<String> onLineTap;
  final ValueChanged<MapTap> onMapTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 지도는 여행 단위로 정한다. 1단계는 네이버만 쓰고, 장소 위치로 고르는 것은 2단계다.
    final map = ref.watch(
      mapProviderProvider(trip.mapProvider ?? MapProviderType.naver),
    );
    final colors = context.appColors;
    final (:markers, :lines, :arrows) = routeOverlays(
      route: route,
      view: view,
      colors: colors,
    );
    final draft = this.draft;
    return map.buildMap(
      MapScene(
        markers: [
          ...markers,
          if (draft != null)
            draftMarker(draft, Theme.of(context).colorScheme, colors),
        ],
        lines: lines,
        arrows: arrows,
        camera: MapCameraRequest(
          key: cameraKey,
          bounds: cameraBoundsFor(view.stops.map((stop) => stop.position)),
        ),
        padding: padding,
        logoLift: logoLift,
      ),
      onMarkerTap: onMarkerTap,
      onLineTap: onLineTap,
      onMapTap: onMapTap,
    );
  }
}

/// 임시 핀을 꽂으면 아래에 뜨는 카드. 추가를 누르면 입력 화면을 연다.
class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.place,
    required this.onAdd,
    required this.onCancel,
  });

  final MapTap place;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = place.placeName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpace.lg, right: AppSpace.xs),
        child: Row(
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                name == null ? l10n.addStopHere : l10n.addNamedStop(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            FilledButton.tonal(onPressed: onAdd, child: Text(l10n.addStop)),
            IconButton(
              tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
              icon: const Icon(Icons.close),
              onPressed: onCancel,
            ),
          ],
        ),
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/stop.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/trip_route.dart';
import '../../../l10n/l10n.dart';
import '../day_itinerary.dart';
import '../route_scene.dart';
import 'itinerary_tiles.dart';
import 'size_reporter.dart';

/// 일차 동선 시트. 지도 아래에서 끌어 올리면 그날의 장소와 구간이 차례로 나온다.
///
/// 손잡이와 제목 줄을 끌면 시트 크기가 바뀌고, 목록을 끌면 시트 크기는 그대로 두고 목록만 넘어간다.
///
/// 접으면 제목 줄([onHeaderSize]로 높이를 알린다)만 보인다. 더 올린 높이는 멈췄을 때만
/// [onLift]로 알린다. 끄는 동안 매 프레임 지도에 넘기면 네이티브 지도가 버벅인다.
class RouteDaySheet extends StatefulWidget {
  const RouteDaySheet({
    super.key,
    required this.trip,
    required this.route,
    required this.itinerary,
    required this.controller,
    required this.headerHeight,
    required this.focus,
    required this.focusCount,
    required this.onHeaderSize,
    required this.onLift,
    required this.onOpenMap,
    required this.onDelete,
    required this.onEdit,
    required this.onStayAgain,
    required this.onReorder,
  });

  final Trip trip;
  final TripRoute route;
  final DayItinerary itinerary;
  final DraggableScrollableController controller;

  /// 제목 줄 높이. 접힌 시트는 이 높이에 아래 시스템 여백을 더한 만큼 보인다.
  final double headerHeight;

  /// 지도에서 눌러서 보여 줄 장소·구간. [focusCount]가 바뀔 때 펼쳐서 보여 준다.
  final List<String> focus;
  final int focusCount;

  final ValueChanged<double> onHeaderSize;

  /// 접힌 높이보다 더 올라온 높이(논리 px).
  final ValueChanged<double> onLift;

  final ValueChanged<Stop> onOpenMap;
  final ValueChanged<Stop> onDelete;
  final ValueChanged<Stop> onEdit;

  /// "오늘 밤도 여기서 묵기"를 누른 전날 밤 숙소.
  final ValueChanged<Stop> onStayAgain;

  /// 끌어서 옮긴 장소. [visibleIds]는 옮기기 전 순서다(출발 숙소 제외). [newIndex]는 옮긴 뒤 자리다.
  final void Function(List<String> visibleIds, int oldIndex, int newIndex)
  onReorder;

  /// 시트를 펼쳤을 때 높이(화면 높이에 대한 비율). 가운데 멈추는 높이도 둔다.
  static const maxSize = 0.7;
  static const midSize = 0.4;

  @override
  State<RouteDaySheet> createState() => RouteDaySheetState();
}

/// 시트가 [extent](화면 높이 [height]에 대한 비율)에 있을 때, 접힌 높이([minSize])보다 더 올라온 높이(논리 px).
///
/// 시트가 멈추는 높이(접힘·가운데·최대) 근처일 때만 값을 내고, 그 사이를 지나는 중이면 null이다.
/// 값은 지금 높이가 아니라 그 멈추는 높이로 낸다. 접힘이면 정확히 0이다.
@visibleForTesting
double? sheetLiftAt(
  double extent, {
  required double minSize,
  required double height,
}) {
  const tolerance = 0.002;
  for (final size in [minSize, RouteDaySheet.midSize, RouteDaySheet.maxSize]) {
    if ((extent - size).abs() < tolerance) return (size - minSize) * height;
  }
  return null;
}

class RouteDaySheetState extends State<RouteDaySheet> {
  /// 펼친 장소.
  String? _expanded;

  /// 고른 장소나 구간. 바탕색이 바뀐다.
  /// 시트에서 줄을 누르면 그 줄 하나만 고른다. 지도에서 합친 마커를 누르면 그 자리의 장소가 모두 들어간다.
  Set<String> _highlighted = {};

  /// 끌어서 옮긴 순서. 저장소가 새 순서를 낼 때까지 한 프레임이라도 예전 자리로 튀지 않게 먼저 보여 준다.
  List<String>? _movedOrder;

  final _keys = <String, GlobalKey>{};

  /// 목록 스크롤. 시트 크기는 제목 줄로만 바꾸고, 목록은 시트 크기와 따로 넘어간다.
  final _listController = ScrollController();

  /// 화면 높이에 대한 접힌 시트의 비율. 그릴 때 정한다.
  double _minSize = 0.1;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    if (widget.focus.isNotEmpty) _showFocus();
  }

  @override
  void didUpdateWidget(RouteDaySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_ids(oldWidget.itinerary), _ids(widget.itinerary))) {
      _movedOrder = null;
    }
    if (widget.focusCount != oldWidget.focusCount && widget.focus.isNotEmpty) {
      _showFocus();
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  static List<String> _ids(DayItinerary itinerary) => [
    for (final s in itinerary.stops) s.stop.id,
  ];

  /// 시트를 접는다. 지도 빈 곳을 누를 때 쓴다.
  void collapse() {
    if (!widget.controller.isAttached) return;
    widget.controller.animateTo(
      _minSize,
      duration: _moveDuration,
      curve: Curves.easeOutCubic,
    );
  }

  static const _moveDuration = Duration(milliseconds: 250);

  void _showFocus() {
    final focus = widget.focus;
    final stopId = focus
        .where((id) => widget.route.stopById(id) != null)
        .firstOrNull;
    // initState와 didUpdateWidget에서 부르고, 바로 다음에 build가 불린다.
    _highlighted = focus.toSet();
    if (stopId != null) _expanded = stopId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.controller.isAttached) return;
      if (widget.controller.size < RouteDaySheet.midSize) {
        await widget.controller.animateTo(
          RouteDaySheet.midSize,
          duration: _moveDuration,
          curve: Curves.easeOutCubic,
        );
      }
      if (!mounted) return;
      final target = focus
          .map((id) => _keys[id]?.currentContext)
          .nonNulls
          .firstOrNull;
      if (target != null && target.mounted) {
        // 제목 줄은 목록 밖에 있어서, 줄 위쪽을 목록 맨 위에 맞추면 가리지 않는다.
        await Scrollable.ensureVisible(target, duration: _moveDuration);
      }
    });
  }

  GlobalKey _keyOf(String id) => _keys[id] ??= GlobalKey();

  /// 장소 줄을 누르면 그 장소를 고르고 펼친다. 이미 펼친 장소면 접기만 하고 고른 것은 그대로 둔다.
  void _tapStop(String id) => setState(() {
    _highlighted = {id};
    _expanded = _expanded == id ? null : id;
  });

  void _tapSegment(String id) => setState(() => _highlighted = {id});

  bool _onExtent(DraggableScrollableNotification notification) {
    final lift = sheetLiftAt(
      notification.extent,
      minSize: _minSize,
      height: _height,
    );
    if (lift != null) widget.onLift(lift);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _height = constraints.maxHeight;
        final peek = widget.headerHeight + insets.bottom;
        _minSize = (peek / _height).clamp(0.05, RouteDaySheet.midSize - 0.05);
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: _onExtent,
          child: DraggableScrollableSheet(
            controller: widget.controller,
            initialChildSize: _minSize,
            minChildSize: _minSize,
            maxChildSize: RouteDaySheet.maxSize,
            snap: true,
            snapSizes: const [RouteDaySheet.midSize],
            builder: (context, scrollController) =>
                _sheet(context, scrollController, insets),
          ),
        );
      },
    );
  }

  Widget _sheet(
    BuildContext context,
    ScrollController scrollController,
    EdgeInsets insets,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final itinerary = widget.itinerary;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.lg.topLeft),
        side: BorderSide(color: colors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 손잡이와 제목 줄. 시트의 스크롤 컨트롤러는 여기에만 붙인다.
          // 그래서 이 줄을 끌면 시트 크기가 바뀌고(멈추는 높이에 맞춘다), 목록을 끌면 목록만 넘어간다.
          // 넘길 내용이 없는 줄이라 끄는 만큼 모두 시트 크기로 간다.
          SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            child: SizeReporter(
              onSize: (size) => widget.onHeaderSize(size.height),
              child: _Header(trip: widget.trip, itinerary: itinerary),
            ),
          ),
          Expanded(child: _list(context, insets)),
        ],
      ),
    );
  }

  /// 그날의 장소와 구간. 시트 크기와 따로 넘어간다.
  Widget _list(BuildContext context, EdgeInsets insets) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final itinerary = widget.itinerary;
    final stops = _ordered(itinerary.stops);
    final visibleIds = [for (final s in stops) s.stop.id];
    final side = EdgeInsets.only(
      left: insets.left + AppSpace.sm,
      right: insets.right + AppSpace.sm,
    );

    Widget stopTile(
      Stop stop, {
      String? caption,
      bool fixed = false,
      int? index,
    }) => ItineraryStopTile(
      key: _keyOf(stop.id),
      stop: stop,
      look: markerLookOf(widget.route, stop, colors),
      caption: caption,
      expanded: _expanded == stop.id,
      highlighted: _highlighted.contains(stop.id),
      onToggle: () => _tapStop(stop.id),
      onOpenMap: () => widget.onOpenMap(stop),
      onDelete: fixed ? null : () => widget.onDelete(stop),
      onEdit: () => widget.onEdit(stop),
      reorderHandle: index == null || stops.length < 2
          ? null
          : ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: l10n.itineraryReorder,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: Icon(
                    Icons.drag_handle,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );

    return CustomScrollView(
      controller: _listController,
      // 지도에서 누른 장소로 넘기려면 화면 밖 줄도 만들어 두어야 한다. 하루 장소는 많지 않다.
      scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
      slivers: [
        if (itinerary.start case final start?)
          SliverPadding(
            padding: side,
            sliver: SliverToBoxAdapter(
              child: stopTile(
                start,
                caption: l10n.itineraryStartLodging,
                fixed: true,
              ),
            ),
          ),
        SliverPadding(
          padding: side,
          sliver: SliverReorderableList(
            itemCount: stops.length,
            onReorderItem: (oldIndex, newIndex) {
              final moved = [...visibleIds];
              final id = moved.removeAt(oldIndex);
              moved.insert(newIndex, id);
              setState(() => _movedOrder = moved);
              widget.onReorder(visibleIds, oldIndex, newIndex);
            },
            proxyDecorator: (child, _, _) => Material(
              color: scheme.surfaceContainerLowest,
              elevation: 4,
              borderRadius: AppRadius.md,
              child: child,
            ),
            itemBuilder: (context, index) {
              final entry = stops[index];
              final arrival = entry.arrival;
              return Column(
                key: ValueKey(entry.stop.id),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (arrival != null && _movedOrder == null)
                    ItinerarySegmentTile(
                      key: _keyOf(arrival.id),
                      segment: arrival,
                      // 선은 도착 장소의 일차 색이다.
                      color: colors.routeDay(entry.stop.day).background,
                      highlighted: _highlighted.contains(arrival.id),
                      onTap: () => _tapSegment(arrival.id),
                    ),
                  stopTile(entry.stop, index: index),
                ],
              );
            },
          ),
        ),
        // 연박: 그날 밤 숙소를 아직 넣지 않았으면 전날 숙소를 한 번에 다시 넣는다.
        if (itinerary.lodgingToStayAgain case final lodging?)
          SliverPadding(
            padding: side.add(const EdgeInsets.only(top: AppSpace.sm)),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => widget.onStayAgain(lodging),
                  icon: const Icon(Icons.bed_outlined),
                  label: Text(l10n.stayAgain(lodging.name)),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: insets.bottom + AppSpace.lg),
        ),
      ],
    );
  }

  /// 끌어서 옮긴 직후에는 옮긴 순서로 보여 준다.
  List<ItineraryStop> _ordered(List<ItineraryStop> stops) {
    final order = _movedOrder;
    if (order == null || order.length != stops.length) return stops;
    final byId = {for (final s in stops) s.stop.id: s};
    if (!order.every(byId.containsKey)) return stops;
    return [for (final id in order) byId[id]!];
  }
}

/// 접힌 시트에 보이는 줄: 손잡이, 일차(와 날짜), 장소 수.
class _Header extends StatelessWidget {
  const _Header({required this.trip, required this.itinerary});

  final Trip trip;
  final DayItinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final day = itinerary.day;
    final dates = trip.dates;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.md,
      ),
      child: Column(
        children: [
          Container(
            width: AppSpace.xxl,
            height: AppSpace.xs,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: AppRadius.sm,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Container(
                width: AppSpace.md,
                height: AppSpace.md,
                decoration: BoxDecoration(
                  color: context.appColors.routeDay(day).background,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  dates == null
                      ? l10n.routeDay(day)
                      : l10n.itineraryTitleWithDate(
                          day,
                          dates.start.addDays(day - 1).toDateTime(),
                        ),
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.itineraryStopCount(itinerary.stops.length),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

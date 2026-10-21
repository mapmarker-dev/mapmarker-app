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

/// 일차 동선 목록에서 펼친 장소와 고른 장소·구간.
///
/// 목록을 감싸는 틀(아래 시트, 오른쪽 패널)이 아니라 화면이 들고 있다.
/// 기기를 돌려 틀이 바뀌어도 펼친 줄과 고른 줄이 남게 하려는 것이다.
class ItinerarySelection extends ChangeNotifier {
  /// 펼친 장소.
  String? expanded;

  /// 고른 장소나 구간. 바탕색이 바뀐다.
  /// 목록에서 줄을 누르면 그 줄 하나만 고른다. 지도에서 합친 마커를 누르면 그 자리의 장소가 모두 들어간다.
  Set<String> highlighted = {};

  /// 마지막으로 보여 준 지도 탭(`RouteChoice.focusCount`). 틀이 바뀌어 목록을 새로 만들어도 같은 탭을 다시 보여 주지 않는다.
  int shownFocusCount = 0;

  /// 장소 줄을 누르면 그 장소를 고르고 펼친다. 이미 펼친 장소면 접기만 하고 고른 것은 그대로 둔다.
  void tapStop(String id) {
    highlighted = {id};
    expanded = expanded == id ? null : id;
    notifyListeners();
  }

  void tapSegment(String id) {
    highlighted = {id};
    notifyListeners();
  }

  /// 지도에서 누른 것을 고른다. [stopId]가 있으면 그 장소를 펼친다.
  void focus(Iterable<String> ids, {String? stopId, required int count}) {
    highlighted = ids.toSet();
    if (stopId != null) expanded = stopId;
    shownFocusCount = count;
    notifyListeners();
  }
}

/// 그날의 장소와 구간 목록. 아래 시트와 오른쪽 패널이 함께 쓴다.
///
/// 장소 줄을 누르면 고르고 펼치며, 손잡이로 끌어 순서를 바꾼다.
/// 지도에서 누른 장소·구간([focus])은 [onReveal]로 틀을 연 뒤 그 줄로 넘긴다.
class DayItineraryList extends StatefulWidget {
  const DayItineraryList({
    super.key,
    required this.route,
    required this.itinerary,
    required this.selection,
    required this.focus,
    required this.focusCount,
    required this.onReveal,
    required this.onOpenMap,
    required this.onDelete,
    required this.onEdit,
    required this.onStayAgain,
    required this.onReorder,
    this.padding = EdgeInsets.zero,
  });

  final TripRoute route;
  final DayItinerary itinerary;
  final ItinerarySelection selection;

  /// 지도에서 눌러서 보여 줄 장소·구간. [focusCount]가 바뀔 때 보여 준다.
  final List<String> focus;
  final int focusCount;

  /// 지도에서 누른 줄로 넘기기 전에 목록이 보이게 틀을 연다(예: 아래 시트를 40%로 올린다).
  final Future<void> Function() onReveal;

  final ValueChanged<Stop> onOpenMap;
  final ValueChanged<Stop> onDelete;
  final ValueChanged<Stop> onEdit;

  /// "오늘 밤도 여기서 묵기"를 누른 전날 밤 숙소.
  final ValueChanged<Stop> onStayAgain;

  /// 끌어서 옮긴 장소. [visibleIds]는 옮기기 전 순서다(출발 숙소 제외). [newIndex]는 옮긴 뒤 자리다.
  final void Function(List<String> visibleIds, int oldIndex, int newIndex)
  onReorder;

  /// 목록 바깥 여백. 아래 시트는 시스템 여백을 더한다.
  final EdgeInsets padding;

  @override
  State<DayItineraryList> createState() => _DayItineraryListState();
}

class _DayItineraryListState extends State<DayItineraryList> {
  /// 끌어서 옮긴 순서. 저장소가 새 순서를 낼 때까지 한 프레임이라도 예전 자리로 튀지 않게 먼저 보여 준다.
  List<String>? _movedOrder;

  final _keys = <String, GlobalKey>{};

  /// 보여 주려고 예약한 지도 탭. 한 프레임에 여러 번 다시 그려져도 한 번만 보여 준다.
  int? _scheduledFocusCount;

  static const _moveDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_onSelection);
    _showFocusIfNew();
  }

  @override
  void didUpdateWidget(DayItineraryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection.removeListener(_onSelection);
      widget.selection.addListener(_onSelection);
    }
    if (!listEquals(_ids(oldWidget.itinerary), _ids(widget.itinerary))) {
      _movedOrder = null;
    }
    _showFocusIfNew();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelection);
    super.dispose();
  }

  void _onSelection() => setState(() {});

  static List<String> _ids(DayItinerary itinerary) => [
    for (final s in itinerary.stops) s.stop.id,
  ];

  /// 지도에서 새로 누른 것이 있으면 고르고, 틀을 연 뒤 그 줄로 넘긴다.
  void _showFocusIfNew() {
    final focus = widget.focus;
    final selection = widget.selection;
    final count = widget.focusCount;
    if (focus.isEmpty ||
        count == selection.shownFocusCount ||
        count == _scheduledFocusCount) {
      return;
    }
    _scheduledFocusCount = count;
    // initState·didUpdateWidget에서 불러서, 알림은 그리기가 끝난 뒤에 보낸다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.focusCount != count) return;
      selection.focus(
        focus,
        stopId: focus
            .where((id) => widget.route.stopById(id) != null)
            .firstOrNull,
        count: widget.focusCount,
      );
      await widget.onReveal();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final selection = widget.selection;
    final itinerary = widget.itinerary;
    final stops = _ordered(itinerary.stops);
    final visibleIds = [for (final s in stops) s.stop.id];
    final side = EdgeInsets.only(
      left: widget.padding.left + AppSpace.sm,
      right: widget.padding.right + AppSpace.sm,
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
      expanded: selection.expanded == stop.id,
      highlighted: selection.highlighted.contains(stop.id),
      onToggle: () => selection.tapStop(stop.id),
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
      // 아래 시트와 오른쪽 패널이 같은 키를 써서, 기기를 돌려 틀이 바뀌어도 넘긴 자리가 남는다.
      key: const PageStorageKey('day-itinerary'),
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
                      highlighted: selection.highlighted.contains(arrival.id),
                      onTap: () => selection.tapSegment(arrival.id),
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
          child: SizedBox(height: widget.padding.bottom + AppSpace.lg),
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

/// 목록의 제목 줄: 일차(와 날짜), 장소 수.
///
/// 아래 시트는 위에 끌기 손잡이를([showHandle]), 오른쪽 패널은 끝에 닫기 버튼을([onClose]) 단다.
class ItineraryHeader extends StatelessWidget {
  const ItineraryHeader({
    super.key,
    required this.trip,
    required this.itinerary,
    this.showHandle = false,
    this.onClose,
  });

  final Trip trip;
  final DayItinerary itinerary;
  final bool showHandle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final day = itinerary.day;
    final dates = trip.dates;
    final onClose = this.onClose;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        onClose == null ? AppSpace.lg : AppSpace.xs,
        onClose == null ? AppSpace.md : AppSpace.xs,
      ),
      child: Column(
        children: [
          if (showHandle) ...[
            Container(
              width: AppSpace.xxl,
              height: AppSpace.xs,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: AppRadius.sm,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
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
              if (onClose != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

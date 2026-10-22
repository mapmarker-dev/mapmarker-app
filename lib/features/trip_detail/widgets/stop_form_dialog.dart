import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_time.dart';
import '../../../data/models/stop.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/trip_route.dart';
import '../../../l10n/l10n.dart';
import '../stop_draft.dart';
import '../stop_placement.dart';
import 'dropped_transport_list.dart';

/// 장소 입력 화면을 띄운다. 저장하면 고친 값을, 그냥 닫으면 null을 돌려준다.
///
/// 칸이 많아 키보드가 올라오면 시트 안에서는 비좁아서 화면 전체를 쓴다.
/// 경로는 만들지 않는다. 링크로 바로 열 일이 없는 화면 상태라서다.
///
/// [stop]은 편집할 장소다. null이면 새 장소를 추가한다.
/// [onDelete]가 있으면 맨 아래에 "장소 지우기"가 있다. 지웠으면(true) 입력 화면을 닫고 null을 돌려준다.
Future<StopDraft?> showStopForm(
  BuildContext context, {
  required Trip trip,
  required TripRoute route,
  required StopDraft initial,
  Stop? stop,
  Future<bool> Function()? onDelete,
}) => showDialog<StopDraft>(
  context: context,
  useSafeArea: false,
  builder: (context) => StopFormDialog(
    trip: trip,
    route: route,
    initial: initial,
    stop: stop,
    onDelete: onDelete,
  ),
);

/// "넣을 자리" 칸의 선택지 글자. 예: "‘숙소’ 앞", "‘동문시장’ 뒤".
///
/// 빈자리는 바로 앞 장소로 가리킨다("‘A’ 뒤"). 맨 앞과 바로 뒤가 숙소인 자리는 뒤 장소로 가리킨다("‘숙소’ 앞").
/// 숙소 앞은 그날 밤 숙소 앞이라는 기본 자리라서, 사용자가 떠올리는 말 그대로 쓴다.
String insertionSlotText(AppLocalizations l10n, InsertionSlot slot) {
  final before = slot.before;
  final after = slot.after;
  if (after != null && (after.isLodging || before == null)) {
    return l10n.stopSlotBefore(after.name);
  }
  if (before != null) return l10n.stopSlotAfter(before.name);
  return l10n.stopSlotOnly;
}

class StopFormDialog extends StatefulWidget {
  const StopFormDialog({
    super.key,
    required this.trip,
    required this.route,
    required this.initial,
    this.stop,
    this.onDelete,
  });

  final Trip trip;

  /// 입력 화면을 열 때의 동선. 넣을 자리의 선택지와 지워질 이동 수단을 여기서 계산한다.
  final TripRoute route;

  final StopDraft initial;

  /// 편집할 장소. null이면 새 장소다.
  final Stop? stop;

  /// 확인을 받아 장소를 지운다. 지웠으면 true다. null이면 지우기가 없다(새 장소, 출발 장소).
  ///
  /// 지우기는 일차 동선 목록이 아니라 여기에 둔다. 목록은 깔끔하게 두고, 지우기는 자주 쓰지 않아서다.
  final Future<bool> Function()? onDelete;

  bool get isNew => stop == null;

  @override
  State<StopFormDialog> createState() => _StopFormDialogState();
}

class _StopFormDialogState extends State<StopFormDialog> {
  late StopDraft _draft = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late final _description = TextEditingController(
    text: widget.initial.description,
  );
  late final _memo = TextEditingController(text: widget.initial.memo);

  /// 처음 값에서 고친 것이 있는지. 있으면 닫기 전에 버릴지 묻는다.
  bool get _dirty => _draft != widget.initial;

  @override
  void initState() {
    super.initState();
    _name.addListener(
      () => setState(() => _draft = _draft.copyWith(name: _name.text)),
    );
    _description.addListener(
      () => setState(
        () => _draft = _draft.copyWith(description: _description.text),
      ),
    );
    _memo.addListener(
      () => setState(() => _draft = _draft.copyWith(memo: _memo.text)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_draft);

  /// 넣을 자리 칸이 보이는지. 새 장소이거나, 편집에서 다른 일차로 옮길 때다.
  /// 같은 일차 안에서 순서를 바꾸는 것은 목록에서 끌어서 한다.
  bool get _placing => widget.stop == null || _draft.day != widget.stop!.day;

  Future<void> _pickTime() async {
    final time = _draft.plannedTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time?.hour ?? 12, minute: time?.minute ?? 0),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _draft = _draft.copyWith(
        plannedTime: () => LocalTime(picked.hour, picked.minute),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.discardChangesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.discardChanges),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final insets = MediaQuery.paddingOf(context);
    const gap = SizedBox(height: AppSpace.lg);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: material.closeButtonTooltip,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              widget.isNew ? l10n.stopFormAddTitle : l10n.stopFormEditTitle,
            ),
            actions: [
              TextButton(
                onPressed: _draft.isValid ? _save : null,
                child: Text(material.saveButtonLabel),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              insets.left + AppSpace.lg,
              AppSpace.lg,
              insets.right + AppSpace.lg,
              insets.bottom + AppSpace.xl,
            ),
            children: [
              TextField(
                controller: _name,
                autofocus: widget.isNew && widget.initial.name.isEmpty,
                maxLength: StopDraft.nameMaxLength,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.stopNameLabel),
              ),
              gap,
              Text(l10n.stopKindLabel, style: textTheme.titleSmall),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final kind in StopKind.values)
                    ChoiceChip(
                      label: Text(l10n.stopKindName(kind)),
                      selected: _draft.kind == kind,
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(kind: kind)),
                    ),
                ],
              ),
              gap,
              DropdownButtonFormField<int>(
                initialValue: _draft.day,
                decoration: InputDecoration(labelText: l10n.stopDayLabel),
                items: [
                  for (var day = 1; day <= widget.trip.nights + 1; day++)
                    DropdownMenuItem(value: day, child: Text(_dayLabel(day))),
                ],
                onChanged: (day) {
                  if (day != null) {
                    // 다른 일차의 자리는 이어지지 않아서, 그 일차의 기본 자리로 돌아간다.
                    setState(
                      () => _draft = _draft.copyWith(
                        day: day,
                        slotOrder: () => null,
                      ),
                    );
                  }
                },
              ),
              if (_placing) ...[
                gap,
                _SlotField(
                  route: widget.route,
                  draft: _draft,
                  stop: widget.stop,
                  onChanged: (order) => setState(
                    () => _draft = _draft.copyWith(slotOrder: () => order),
                  ),
                ),
              ],
              gap,
              _TimeField(
                time: _draft.plannedTime,
                onPick: _pickTime,
                onClear: () => setState(
                  () => _draft = _draft.copyWith(plannedTime: () => null),
                ),
              ),
              gap,
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 6,
                maxLength: StopDraft.textMaxLength,
                decoration: InputDecoration(
                  labelText: l10n.stopDescriptionLabel,
                  helperText: l10n.stopDescriptionHelper,
                  alignLabelWithHint: true,
                ),
              ),
              gap,
              TextField(
                controller: _memo,
                minLines: 2,
                maxLines: 6,
                maxLength: StopDraft.textMaxLength,
                decoration: InputDecoration(
                  labelText: l10n.stopMemoLabel,
                  helperText: l10n.stopMemoHelper,
                  alignLabelWithHint: true,
                ),
              ),
              if (widget.onDelete case final onDelete?) ...[
                const SizedBox(height: AppSpace.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    // 저장하지 않은 고친 내용이 있어도 장소를 지우면 함께 버린다. 따로 묻지 않는다.
                    onPressed: () async {
                      if (await onDelete() && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.stopFormDelete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(int day) {
    final l10n = context.l10n;
    final dates = widget.trip.dates;
    return dates == null
        ? l10n.routeDay(day)
        : l10n.itineraryTitleWithDate(
            day,
            dates.start.addDays(day - 1).toDateTime(),
          );
  }
}

/// "넣을 자리" 칸과, 그 자리에 넣으면 지워질 이동 수단의 미리 알림.
///
/// 고르지 않았으면 기본 자리(맨 뒤, 마지막이 숙소면 숙소 앞)를 가리키고 "(기본)"을 붙인다.
/// 고르지 않은 동안은 종류를 바꾸면 기본 자리도 따라 바뀐다(숙소는 맨 뒤).
/// 미리 알림을 보고 저장하는 것이라, 저장할 때 따로 묻지 않는다.
class _SlotField extends StatelessWidget {
  const _SlotField({
    required this.route,
    required this.draft,
    required this.stop,
    required this.onChanged,
  });

  final TripRoute route;
  final StopDraft draft;
  final Stop? stop;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dayStops = dayStopsOf(route, draft.day, stopId: stop?.id);
    final slots = insertionSlots(dayStops, draft.kind);
    final defaultOrder = insertionOrder(dayStops, draft.kind);
    final selected = placedOrder(route, draft, stopId: stop?.id);
    final dropped = transportsDroppedByDraft(route, draft, stop: stop);
    final error = Theme.of(context).colorScheme.error;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          // 처음 값만 읽는 칸이라, 일차·기본 자리가 바뀌면 새로 만든다.
          key: ValueKey(('slot', draft.day, selected)),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.stopSlotLabel),
          items: [
            for (final slot in slots)
              DropdownMenuItem(
                value: slot.order,
                child: Text(
                  slots.length > 1 && slot.order == defaultOrder
                      ? l10n.stopSlotDefault(insertionSlotText(l10n, slot))
                      : insertionSlotText(l10n, slot),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          // 장소가 없는 일차는 자리가 하나뿐이라 고를 것이 없다.
          disabledHint: Text(insertionSlotText(l10n, slots.first)),
          onChanged: slots.length > 1
              ? (order) {
                  if (order != null) onChanged(order);
                }
              : null,
        ),
        if (dropped.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: error),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop == null
                            ? l10n.stopSlotDropsTransportAdd
                            : l10n.stopSlotDropsTransportMove,
                        style: textTheme.bodyMedium?.copyWith(color: error),
                      ),
                      DroppedTransportList(route: route, segments: dropped),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 예정 시각 칸. 누르면 시각을 고르고, 정한 시각은 ✕로 지운다.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.time,
    required this.onPick,
    required this.onClear,
  });

  final LocalTime? time;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = this.time;
    return InkWell(
      onTap: onPick,
      borderRadius: AppRadius.sm,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.stopTimeLabel,
          suffixIcon: time == null
              ? const Icon(Icons.schedule)
              : IconButton(
                  tooltip: l10n.stopTimeClear,
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          time == null
              ? l10n.stopTimeNone
              : MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay(hour: time.hour, minute: time.minute),
                ),
        ),
      ),
    );
  }
}

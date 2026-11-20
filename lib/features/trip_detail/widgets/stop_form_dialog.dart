import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/zoned_time.dart';
import '../../../core/widgets/form_saving.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/segment.dart';
import '../../../data/models/stop.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/trip_route.dart';
import '../../../data/trips/route_links.dart';
import '../../../l10n/l10n.dart';
import '../stop_draft.dart';
import '../stop_placement.dart';
import '../stop_visit.dart';
import 'dropped_transport_list.dart';
import 'place_fields.dart';
import 'place_photo_field.dart';
import 'stop_photo.dart';
import 'time_wheel_sheet.dart';

/// 장소 입력 화면을 띄운다. 저장하면 고친 값을, 그냥 닫으면 null을 돌려준다.
///
/// 칸이 많아 키보드가 올라오면 시트 안에서는 비좁아서 화면 전체를 쓴다.
/// 경로는 만들지 않는다. 링크로 바로 열 일이 없는 화면 상태라서다.
///
/// [stop]은 편집할 장소다. null이면 새 장소를 추가한다.
/// [onSave]로 저장되면 고친 값을 돌려주며 닫히고, 그냥 닫으면 null이다.
/// [onDelete]가 있으면 맨 아래에 "장소 지우기"가 있다. 확인을 받아 지우면 입력 화면을 닫고 null을 돌려준다.
/// [onDemote]가 있으면 그 위에 "후보로 빼기"가 있다. 빼면 입력 화면을 닫고 null을 돌려준다.
/// 저장하거나 지우지 못하면 입력한 그대로 열려 있고 화면 안에 알린다([FormSaving]).
/// [title]은 새 장소 제목("장소 추가") 대신 쓸 제목이다(후보를 동선에 넣을 때).
Future<StopDraft?> showStopForm(
  BuildContext context, {
  required Trip trip,
  required TripRoute route,
  required StopDraft initial,
  required Future<void> Function(StopDraft draft) onSave,
  Stop? stop,
  String? title,
  Future<void> Function()? onDelete,
  Future<void> Function(StopDraft draft)? onDemote,
  bool relocatable = true,
  LocalDate? today,
}) => showDialog<StopDraft>(
  context: context,
  useSafeArea: false,
  builder: (context) => StopFormDialog(
    trip: trip,
    route: route,
    initial: initial,
    stop: stop,
    title: title,
    onSave: onSave,
    onDelete: onDelete,
    onDemote: onDemote,
    relocatable: relocatable,
    today: today,
  ),
);

class StopFormDialog extends StatefulWidget {
  const StopFormDialog({
    super.key,
    required this.trip,
    required this.route,
    required this.initial,
    required this.onSave,
    this.stop,
    this.title,
    this.onDelete,
    this.onDemote,
    this.relocatable = true,
    this.today,
  });

  final Trip trip;

  /// 입력 화면을 열 때의 동선. 들어갈 자리와 지워질 이동 수단을 여기서 계산한다.
  final TripRoute route;

  final StopDraft initial;

  /// 편집할 장소. null이면 새 장소다.
  final Stop? stop;

  /// 고친 값을 저장한다. 저장하지 못하면 `ApiException`을 던진다.
  final Future<void> Function(StopDraft draft) onSave;

  /// 장소를 지운다(확인은 이 화면이 받는다). 지우지 못하면 `ApiException`을 던진다.
  /// null이면 지우기가 없다(새 장소, 출발 장소).
  ///
  /// 지우기는 일차 동선 목록이 아니라 여기에 둔다. 목록은 깔끔하게 두고, 지우기는 자주 쓰지 않아서다.
  final Future<void> Function()? onDelete;

  /// 장소를 후보로 뺀다. 입력 화면의 이름·종류·설명·메모를 고쳤으면 그 값으로 빼야 해서 지금 값을 넘긴다.
  /// 빼지 못하면 `ApiException`을 던진다. null이면 없다(새 장소, 출발 장소).
  ///
  /// 사라지는 것(이동 수단을 적은 닿은 구간, 예정 시각)이 있을 때만 이 화면이 확인을 받는다.
  /// 후보는 다시 넣을 수 있어서, 잃는 것이 없으면 묻지 않는다.
  final Future<void> Function(StopDraft draft)? onDemote;

  /// 제목. null이면 새 장소는 "장소 추가", 편집은 "장소 편집"이다.
  final String? title;

  /// 주소 칸에서 찾아 위치를 바꿀 수 있는지. [동선에 넣기]는 좌표를 후보 것으로 써서 false다.
  final bool relocatable;

  /// 오늘(기기 날짜). 방문 날짜는 오늘까지만 고른다. null이면 기기 시계로 읽는다.
  final LocalDate? today;

  bool get isNew => stop == null;

  @override
  State<StopFormDialog> createState() => _StopFormDialogState();
}

class _StopFormDialogState extends State<StopFormDialog> with FormSaving {
  late StopDraft _draft = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late final _description = TextEditingController(
    text: widget.initial.description,
  );
  late final _memo = TextEditingController(text: widget.initial.memo);
  late final _address = TextEditingController(text: widget.initial.address);

  /// 처음 값에서 고친 것이 있는지. 있으면 닫기 전에 버릴지 묻는다.
  bool get _dirty => _draft != widget.initial;

  /// 고른 사진을 줄이는 중. 그동안은 저장하지 않는다(고른 사진이 빠진 채 저장되지 않게).
  bool _preparingPhoto = false;

  /// 후보로 빼면 함께 사라질 사진의 썸네일. 화면에 보이는 사진(새로 고른 것이 먼저)이고, 없으면 null이다.
  Widget? get _demotedPhoto => switch ((_draft.newPhoto, widget.stop?.photo)) {
    (final picked?, _) => Image.memory(picked.thumbnail, fit: BoxFit.cover),
    (null, final saved?) when !_draft.removePhoto => StopPhotoImage(saved),
    _ => null,
  };

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
    _address.addListener(
      () => setState(() => _draft = _draft.copyWith(address: _address.text)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _memo.dispose();
    _address.dispose();
    super.dispose();
  }

  /// 지우는 중인지. 저장 중 표시를 저장 버튼이 아닌 지우기 버튼에 띄운다.
  bool _deleting = false;

  void _save() {
    final draft = _draft;
    saveAndClose(() => widget.onSave(draft), draft);
  }

  /// 확인을 받아 지운다. 저장하지 않은 고친 내용이 있어도 장소를 지우면 함께 버린다. 따로 묻지 않는다.
  Future<void> _delete(Future<void> Function() delete) async {
    final l10n = context.l10n;
    final confirmed = await confirmDelete(
      context,
      title: l10n.deleteStopTitle(widget.stop?.name ?? _draft.name),
      message: widget.stop?.photo != null
          ? l10n.deleteStopMessageWithPhoto
          : l10n.deleteStopMessage,
      // 장소를 지우면 저장된 사진이 사라진다(입력 화면에서 고친 것은 함께 버린다).
      detail: switch (widget.stop?.photo) {
        final photo? => LostPhotoLine(image: StopPhotoImage(photo)),
        null => null,
      },
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    await saveAndClose(delete);
    if (mounted) setState(() => _deleting = false);
  }

  /// 후보로 빼는 중인지. 저장 중 표시를 "후보로 빼기" 버튼에 띄운다.
  bool _demoting = false;

  /// 후보로 뺀다. 이동 수단을 적은 닿은 구간이나 예정 시각이 사라지면 먼저 묻는다.
  /// 예정 시각은 입력 화면에 보이는 값이다(지운 시각은 잃을 것이 없다).
  Future<void> _demote(Future<void> Function(StopDraft draft) demote) async {
    final stop = widget.stop;
    if (stop == null) return;
    final draft = _draft;
    final dropped = withTransport(
      segmentsDroppedByRemove(segments: widget.route.segments, stopId: stop.id),
    );
    final time = draft.plannedTime;
    final photo = _demotedPhoto;
    if (dropped.isNotEmpty || time != null || photo != null) {
      final confirmed = await _confirmDemote(
        name: stop.name,
        dropped: dropped,
        time: time,
        photo: photo,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _demoting = true);
    await saveAndClose(() => demote(draft));
    if (mounted) setState(() => _demoting = false);
  }

  Future<bool> _confirmDemote({
    required String name,
    required List<Segment> dropped,
    required LocalTime? time,
    required Widget? photo,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        final material = MaterialLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.demoteStopTitle(name)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.demoteStopMessage),
                if (time != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.md),
                    child: Text(
                      l10n.demoteStopPlannedTime(
                        material.formatTimeOfDay(
                          TimeOfDay(hour: time.hour, minute: time.minute),
                        ),
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                if (photo != null) LostPhotoLine(image: photo),
                DroppedTransportList(route: widget.route, segments: dropped),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(material.cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.demoteStopConfirm),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  /// 넣거나 다른 일차로 옮기는지. 지워질 이동 수단을 미리 알린다.
  /// 같은 일차 안에서 순서를 바꾸는 것은 목록에서 끌어서 한다.
  bool get _placing => widget.stop == null || _draft.day != widget.stop!.day;

  /// 제목. ⊕로 연 새 장소는 넣을 자리 칸이 없어서 어디에 넣는지를 제목으로 보인다
  /// ("2일차 c → d 사이에 넣기"). 일차를 바꾸면 기본 자리라 보통 제목으로 돌아간다.
  String _titleText(AppLocalizations l10n) {
    if (widget.title case final title?) return title;
    if (!widget.isNew) return l10n.stopFormEditTitle;
    final order = _draft.slotOrder;
    if (order != null) {
      final slot = insertionSlots(
        dayStopsOf(widget.route, _draft.day),
        _draft.kind,
      ).where((slot) => slot.order == order).firstOrNull;
      if (slot case InsertionSlot(:final before?, :final after?)) {
        return l10n.placeFinderTitleBetween(
          _draft.day,
          before.name,
          after.name,
        );
      }
    }
    return l10n.stopFormAddTitle;
  }

  Future<void> _pickTime() async {
    final picked = await showTimeWheel(context, initial: _draft.plannedTime);
    if (picked == null || !mounted) return;
    setState(() => _draft = _draft.copyWith(plannedTime: () => picked));
  }

  /// 방문 시각의 시간대. 장소의 것이고, 새 장소는 기본 시간대다(방문 칸이 없다).
  String get _timeZone => widget.stop?.timeZone ?? Stop.defaultTimeZone;

  /// 방문 날짜를 달력으로 고친다. 시각은 그대로다. 고를 수 있는 날은 [visitDateRange]다.
  Future<void> _pickVisitDate() async {
    final at = _draft.visitedAt;
    if (at == null) return;
    final parts = zonedParts(at, _timeZone);
    final range = visitDateRange(
      widget.trip,
      widget.today ?? LocalDate.fromDateTime(DateTime.now()),
    );
    var initial = parts.date;
    if (initial.isBefore(range.first)) initial = range.first;
    if (initial.isAfter(range.last)) initial = range.last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.toDateTime(),
      firstDate: range.first.toDateTime(),
      lastDate: range.last.toDateTime(),
      helpText: context.l10n.stopVisitDateHelp,
    );
    if (picked == null || !mounted) return;
    final date = LocalDate.fromDateTime(picked);
    setState(
      () => _draft = _draft.copyWith(
        visitedAt: zonedInstant(date, parts.time, _timeZone),
      ),
    );
  }

  /// 방문 시각을 휠(1분 단위)로 고친다. 날짜는 그대로다.
  Future<void> _pickVisitTime() async {
    final at = _draft.visitedAt;
    if (at == null) return;
    final parts = zonedParts(at, _timeZone);
    final picked = await showTimeWheel(
      context,
      initial: parts.time,
      title: context.l10n.stopVisitLabel,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _draft = _draft.copyWith(
        visitedAt: zonedInstant(parts.date, picked, _timeZone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final insets = MediaQuery.paddingOf(context);
    const gap = SizedBox(height: AppSpace.lg);

    final error = saveError;

    return PopScope(
      canPop: !_dirty && !saving,
      onPopInvokedWithResult: (didPop, _) async {
        // 저장하는 동안은 닫지 않는다.
        if (didPop || saving) return;
        if (await confirmDiscardChanges(context) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: material.closeButtonTooltip,
              icon: const Icon(Icons.close),
              onPressed: saving ? null : () => Navigator.of(context).maybePop(),
            ),
            title: Text(_titleText(l10n)),
            actions: [
              if (saving && !_deleting && !_demoting)
                SavingIndicator(label: l10n.saving)
              else
                TextButton(
                  onPressed: _draft.isValid && !saving && !_preparingPhoto
                      ? _save
                      : null,
                  child: Text(material.saveButtonLabel),
                ),
            ],
          ),
          body: SavingFormBody(
            saving: saving,
            error: error,
            insets: insets,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                insets.left + AppSpace.lg,
                AppSpace.lg,
                insets.right + AppSpace.lg,
                insets.bottom + AppSpace.xl,
              ),
              children: [
                PlaceNameField(
                  controller: _name,
                  enabled: !saving,
                  autofocus: widget.isNew && widget.initial.name.isEmpty,
                ),
                gap,
                PlaceAddressSearch(
                  controller: _address,
                  enabled: !saving,
                  searchable: widget.relocatable,
                  // 고르면 주소 칸은 그 주소가 되고(칸이 바꾼다), 저장할 때 위치를 옮긴다.
                  onPicked: (found) => setState(
                    () => _draft = _draft.copyWith(
                      relocatedTo: () => found.position,
                    ),
                  ),
                ),
                gap,
                PlaceKindChips(
                  kind: _draft.kind,
                  onChanged: (kind) =>
                      setState(() => _draft = _draft.copyWith(kind: kind)),
                ),
                gap,
                DropdownButtonFormField<int>(
                  initialValue: _draft.day,
                  style: Theme.of(context).textTheme.bodyLarge,
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
                if (_placing)
                  _DroppedTransportNotice(
                    route: widget.route,
                    draft: _draft,
                    stop: widget.stop,
                  ),
                gap,
                _TimeField(
                  time: _draft.plannedTime,
                  onPick: _pickTime,
                  onClear: () => setState(
                    () => _draft = _draft.copyWith(plannedTime: () => null),
                  ),
                ),
                if (_draft.visitedAt case final visitedAt?) ...[
                  gap,
                  _VisitField(
                    parts: zonedParts(visitedAt, _timeZone),
                    onPickDate: _pickVisitDate,
                    onPickTime: _pickVisitTime,
                  ),
                ],
                gap,
                PlaceNotesFields(
                  description: _description,
                  memo: _memo,
                  enabled: !saving,
                ),
                gap,
                PlacePhotoField(
                  current: widget.stop?.photo,
                  picked: _draft.newPhoto,
                  removed: _draft.removePhoto,
                  enabled: !saving,
                  onPicked: (photo) => setState(
                    () => _draft = _draft.copyWith(
                      newPhoto: () => photo,
                      removePhoto: false,
                    ),
                  ),
                  onRemoved: () => setState(
                    () => _draft = _draft.copyWith(
                      newPhoto: () => null,
                      // 저장된 사진이 없으면(새로 고른 것만 버림) 지울 것이 없다.
                      removePhoto: widget.stop?.photo != null,
                    ),
                  ),
                  onPreparing: (preparing) =>
                      setState(() => _preparingPhoto = preparing),
                ),
                if (widget.onDemote != null || widget.onDelete != null) ...[
                  // 위는 장소의 내용, 아래는 장소에 하는 동작이라 선으로 나눈다.
                  const SizedBox(height: AppSpace.xl),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpace.lg),
                  FormActionRow(
                    children: [
                      if (widget.onDemote case final onDemote?)
                        FormActionButton(
                          icon: Icons.bookmark_border,
                          label: l10n.stopFormDemote,
                          // 고친 이름·종류·설명·메모로 빼므로, 저장할 수 없는 값이면 뺄 수도 없다.
                          onPressed:
                              saving || !_draft.isValid || _preparingPhoto
                              ? null
                              : () => _demote(onDemote),
                          busy: _demoting,
                        ),
                      if (widget.onDelete case final onDelete?)
                        FormActionButton(
                          icon: Icons.delete_outline,
                          label: l10n.stopFormDelete,
                          onPressed: saving ? null : () => _delete(onDelete),
                          busy: _deleting,
                          danger: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
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

/// 이 장소를 넣으면(옮기면) 지워질 이동 수단의 미리 알림. 지워질 것이 없으면 아무것도 없다.
///
/// 넣을 자리는 고르지 않는다. ⊕로 연 새 장소는 그 자리, 나머지는 기본 자리(맨 뒤, 마지막이 숙소면 숙소 앞)에 넣고, 같은 일차 안 순서는 목록에서 끌어 바꾼다.
/// 미리 알림을 보고 저장하는 것이라, 저장할 때 따로 묻지 않는다.
class _DroppedTransportNotice extends StatelessWidget {
  const _DroppedTransportNotice({
    required this.route,
    required this.draft,
    required this.stop,
  });

  final TripRoute route;
  final StopDraft draft;
  final Stop? stop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dropped = transportsDroppedByDraft(route, draft, stop: stop);
    if (dropped.isEmpty) return const SizedBox.shrink();
    final error = Theme.of(context).colorScheme.error;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
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
    );
  }
}

/// 방문 시각 칸. 방문한 장소에만 있다. 왼쪽 날짜를 누르면 달력, 오른쪽 시각을 누르면 휠로 고친다.
/// 날짜와 시각은 장소 현지 것이다. 지우기(방문 취소)는 펼친 장소 줄의 [방문 취소]다.
class _VisitField extends StatelessWidget {
  const _VisitField({
    required this.parts,
    required this.onPickDate,
    required this.onPickTime,
  });

  final ({LocalDate date, LocalTime time}) parts;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodyLarge;
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget part({
      required String text,
      required IconData icon,
      required VoidCallback onTap,
    }) => InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          children: [
            Flexible(child: Text(text, style: style)),
            const SizedBox(width: AppSpace.xs),
            Icon(icon, size: 18, color: iconColor),
          ],
        ),
      ),
    );
    return InputDecorator(
      decoration: InputDecoration(labelText: l10n.stopVisitLabel),
      child: Row(
        children: [
          Expanded(
            child: part(
              text: l10n.stopVisitDate(parts.date.toDateTime()),
              icon: Icons.calendar_today_outlined,
              onTap: onPickDate,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: part(
              text: MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay(hour: parts.time.hour, minute: parts.time.minute),
              ),
              icon: Icons.schedule,
              onTap: onPickTime,
            ),
          ),
        ],
      ),
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
      // 칸 모양(AppRadius.md)과 같은 모서리로 물결을 그린다.
      borderRadius: AppRadius.md,
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
          style: Theme.of(context).textTheme.bodyLarge,
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

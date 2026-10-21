import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_time.dart';
import '../../../data/models/stop.dart';
import '../../../data/models/trip.dart';
import '../../../l10n/l10n.dart';
import '../stop_draft.dart';

/// 장소 입력 화면을 띄운다. 저장하면 고친 값을, 그냥 닫으면 null을 돌려준다.
///
/// 칸이 많아 키보드가 올라오면 시트 안에서는 비좁아서 화면 전체를 쓴다.
/// 경로는 만들지 않는다. 링크로 바로 열 일이 없는 화면 상태라서다.
///
/// [onDelete]가 있으면 맨 아래에 "장소 지우기"가 있다. 지웠으면(true) 입력 화면을 닫고 null을 돌려준다.
Future<StopDraft?> showStopForm(
  BuildContext context, {
  required Trip trip,
  required StopDraft initial,
  required bool isNew,
  Future<bool> Function()? onDelete,
  Future<bool> Function(StopDraft draft)? confirmSave,
}) => showDialog<StopDraft>(
  context: context,
  useSafeArea: false,
  builder: (context) => StopFormDialog(
    trip: trip,
    initial: initial,
    isNew: isNew,
    onDelete: onDelete,
    confirmSave: confirmSave,
  ),
);

class StopFormDialog extends StatefulWidget {
  const StopFormDialog({
    super.key,
    required this.trip,
    required this.initial,
    required this.isNew,
    this.onDelete,
    this.confirmSave,
  });

  final Trip trip;
  final StopDraft initial;
  final bool isNew;

  /// 확인을 받아 장소를 지운다. 지웠으면 true다. null이면 지우기가 없다(새 장소, 출발 숙소).
  ///
  /// 지우기는 일차 동선 목록이 아니라 여기에 둔다. 목록은 깔끔하게 두고, 지우기는 자주 쓰지 않아서다.
  final Future<bool> Function()? onDelete;

  /// [저장]을 누르면 닫기 전에 부른다. false면 닫지 않고 입력 화면에 남는다.
  /// 예: 일차를 바꿔서 이웃 구간의 이동 수단이 지워질 때 묻고, 취소하면 다시 고칠 수 있게 한다.
  final Future<bool> Function(StopDraft draft)? confirmSave;

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

  Future<void> _save() async {
    final draft = _draft;
    final confirmSave = widget.confirmSave;
    if (confirmSave != null && !await confirmSave(draft)) return;
    if (mounted) Navigator.of(context).pop(draft);
  }

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
                    setState(() => _draft = _draft.copyWith(day: day));
                  }
                },
              ),
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

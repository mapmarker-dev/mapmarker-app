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
Future<StopDraft?> showStopForm(
  BuildContext context, {
  required Trip trip,
  required StopDraft initial,
  required bool isNew,
}) => showDialog<StopDraft>(
  context: context,
  useSafeArea: false,
  builder: (context) =>
      StopFormDialog(trip: trip, initial: initial, isNew: isNew),
);

class StopFormDialog extends StatefulWidget {
  const StopFormDialog({
    super.key,
    required this.trip,
    required this.initial,
    required this.isNew,
  });

  final Trip trip;
  final StopDraft initial;
  final bool isNew;

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

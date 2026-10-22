import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/segment.dart';
import '../../../l10n/l10n.dart';
import '../transport_draft.dart';
import '../transport_look.dart';

/// 이동 수단 입력 화면을 띄운다. 저장하면 고친 값을, 그냥 닫으면 null을 돌려준다.
///
/// 토막이 여러 개이고 숫자 키보드가 올라와서 장소 입력 화면처럼 화면 전체를 쓴다.
/// 경로는 만들지 않는다. 링크로 바로 열 일이 없는 화면 상태라서다.
Future<TransportDraft?> showTransportForm(
  BuildContext context, {
  required TransportDraft initial,
  required String from,
  required String to,
}) => showDialog<TransportDraft>(
  context: context,
  useSafeArea: false,
  builder: (context) =>
      TransportFormDialog(initial: initial, from: from, to: to),
);

/// 구간 하나의 이동 수단. 토막을 갈아타는 차례대로 카드로 늘어놓는다.
///
/// - 아래의 수단 칩을 누르면 그 수단이 맨 뒤에 이어진다. 미정이면 칩 하나만 누르고 저장하면 된다.
/// - 토막의 순서는 앞·뒤 버튼으로 바꾼다. 토막은 보통 2~3개라 끌기보다 정확하고,
///   대화상자 안에서 끌어 옮기면 키보드·스크롤과 부딪힌다.
/// - 토막을 모두 지우고 저장하면 미정으로 돌아간다.
class TransportFormDialog extends StatefulWidget {
  const TransportFormDialog({
    super.key,
    required this.initial,
    required this.from,
    required this.to,
  });

  final TransportDraft initial;

  /// 출발·도착 장소 이름. 제목 아래에 보여 준다.
  final String from;
  final String to;

  @override
  State<TransportFormDialog> createState() => _TransportFormDialogState();
}

class _TransportFormDialogState extends State<TransportFormDialog> {
  late final _legs = [
    for (final leg in widget.initial.legs) _LegFields(leg, _changed),
  ];

  TransportDraft get _draft =>
      TransportDraft([for (final fields in _legs) fields.draft]);

  /// 처음 값에서 고친 것이 있는지. 있으면 닫기 전에 버릴지 묻는다.
  bool get _dirty => _draft != widget.initial;

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final fields in _legs) {
      fields.dispose();
    }
    super.dispose();
  }

  void _add(TransportMode mode) =>
      setState(() => _legs.add(_LegFields(LegDraft(mode), _changed)));

  void _move(int index, int by) => setState(() {
    final fields = _legs.removeAt(index);
    _legs.insert(index + by, fields);
  });

  void _remove(int index) {
    final fields = _legs[index];
    setState(() => _legs.removeAt(index));
    // 이번 프레임에는 아직 칸이 컨트롤러를 붙들고 있어서, 다 그린 뒤에 버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) => fields.dispose());
  }

  void _save() => Navigator.of(context).pop(_draft);

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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final insets = MediaQuery.paddingOf(context);
    final draft = _draft;

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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.transportFormTitle),
                Text(
                  l10n.transportFormRoute(widget.from, widget.to),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: draft.isValid ? _save : null,
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
              if (_legs.isEmpty)
                Text(
                  l10n.transportFormEmpty,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              for (final (i, fields) in _legs.indexed)
                Padding(
                  key: ObjectKey(fields),
                  padding: const EdgeInsets.only(bottom: AppSpace.md),
                  child: _LegCard(
                    fields: fields,
                    onModeChanged: (mode) => setState(() => fields.mode = mode),
                    onMoveUp: i == 0 ? null : () => _move(i, -1),
                    onMoveDown: i == _legs.length - 1
                        ? null
                        : () => _move(i, 1),
                    onDelete: () => _remove(i),
                  ),
                ),
              const SizedBox(height: AppSpace.sm),
              if (draft.canAddLeg) ...[
                Text(
                  _legs.isEmpty
                      ? l10n.transportPickFirst
                      : l10n.transportAddTransfer,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final mode in TransportMode.values)
                      ActionChip(
                        avatar: Icon(transportIcon(mode)),
                        label: Text(l10n.transportModeName(mode)),
                        onPressed: () => _add(mode),
                      ),
                  ],
                ),
              ] else
                Text(
                  l10n.transportMaxLegs(TransportDraft.maxLegs),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 토막 하나의 수단과 칸들. 카드의 순서가 바뀌어도 적은 글자가 따라가게 컨트롤러를 함께 묶는다.
class _LegFields {
  _LegFields(LegDraft leg, VoidCallback onChanged)
    : mode = leg.mode,
      stops = TextEditingController(text: leg.stops),
      hours = TextEditingController(text: leg.hours),
      minutes = TextEditingController(text: leg.minutes) {
    stops.addListener(onChanged);
    hours.addListener(onChanged);
    minutes.addListener(onChanged);
  }

  TransportMode mode;
  final TextEditingController stops;
  final TextEditingController hours;
  final TextEditingController minutes;

  LegDraft get draft => LegDraft(
    mode,
    stops: stops.text,
    hours: hours.text,
    minutes: minutes.text,
  );

  void dispose() {
    stops.dispose();
    hours.dispose();
    minutes.dispose();
  }
}

/// 숫자 칸의 폭. 두 자리 숫자와 뒤에 붙는 글자(정류장, 시간, 분)가 들어간다.
const _numberFieldWidth = 112.0;

class _LegCard extends StatelessWidget {
  const _LegCard({
    required this.fields,
    required this.onModeChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final _LegFields fields;
  final ValueChanged<TransportMode> onModeChanged;

  /// null이면 맨 앞(맨 뒤)이라 옮길 수 없다.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final draft = fields.draft;
    final mode = fields.mode;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.xs,
          AppSpace.xs,
          AppSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PopupMenuButton<TransportMode>(
                      tooltip: l10n.transportChangeMode,
                      initialValue: mode,
                      onSelected: onModeChanged,
                      itemBuilder: (context) => [
                        for (final m in TransportMode.values)
                          PopupMenuItem(
                            value: m,
                            child: Row(
                              children: [
                                Icon(transportIcon(m)),
                                const SizedBox(width: AppSpace.md),
                                Text(l10n.transportModeName(m)),
                              ],
                            ),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(transportIcon(mode), color: scheme.primary),
                            const SizedBox(width: AppSpace.sm),
                            Text(
                              l10n.transportModeName(mode),
                              style: textTheme.titleSmall,
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.transportMoveLegUp,
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: onMoveUp,
                ),
                IconButton(
                  tooltip: l10n.transportMoveLegDown,
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: onMoveDown,
                ),
                IconButton(
                  tooltip: l10n.transportDeleteLeg,
                  icon: const Icon(Icons.delete_outline),
                  color: scheme.error,
                  onPressed: onDelete,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (countsStops(mode)) ...[
                    _NumberField(
                      controller: fields.stops,
                      label: l10n.transportStopsLabel,
                      suffix: l10n.transportStopsSuffix,
                      error: draft.stopsValid
                          ? null
                          : l10n.transportNumberRange(1, LegDraft.maxStops),
                    ),
                    const SizedBox(height: AppSpace.md),
                  ],
                  Text(
                    l10n.transportDurationLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NumberField(
                        controller: fields.hours,
                        suffix: l10n.transportHoursLabel,
                        error: draft.hoursValid
                            ? null
                            : l10n.transportNumberRange(0, LegDraft.maxHours),
                      ),
                      const SizedBox(width: AppSpace.md),
                      _NumberField(
                        controller: fields.minutes,
                        suffix: l10n.transportMinutesLabel,
                        error: draft.minutesValid
                            ? null
                            : l10n.transportNumberRange(0, LegDraft.maxMinutes),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 두 자리 숫자 칸. 숫자 키보드를 띄우고 숫자만 받는다.
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.suffix,
    required this.error,
    this.label,
  });

  final TextEditingController controller;
  final String? label;
  final String suffix;
  final String? error;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _numberFieldWidth,
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: error,
        errorMaxLines: 2,
      ),
    ),
  );
}

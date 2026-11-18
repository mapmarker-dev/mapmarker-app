import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/stop.dart';
import '../../../l10n/l10n.dart';
import '../stop_draft.dart';
import 'address_search.dart';

/// 장소 입력 화면과 후보 입력 화면이 함께 쓰는 칸과 버튼.
/// 후보는 동선에 넣으면 장소가 되니, 같은 값은 같은 칸·같은 상한으로 받는다.

/// 이름 칸.
class PlaceNameField extends StatelessWidget {
  const PlaceNameField({
    super.key,
    required this.controller,
    required this.enabled,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    autofocus: autofocus,
    maxLength: StopDraft.nameMaxLength,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: context.l10n.stopNameLabel,
      // 주소로 찾은 곳도 어떤 가게인지는 모르니 이름은 사용자가 쓴다.
      hintText: context.l10n.stopNameHint,
    ),
  );
}

/// 입력 화면의 주소 칸. 🔍·엔터로 찾아 목록에서 고르면 주소와 위치가 함께 바뀌고, 글자만 고치면 위치는 그대로다.
class PlaceAddressSearch extends StatelessWidget {
  const PlaceAddressSearch({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onPicked,
    this.searchable = true,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<FoundPlace> onPicked;

  /// false면 고칠 수 없는 칸이다. [동선에 넣기]는 후보의 위치 그대로 넣어서(서버가 후보 좌표를 쓴다)
  /// 주소를 찾거나 고쳐도 소용이 없다. 칸 아래에 그 이유와 바꾸는 곳을 알린다.
  final bool searchable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!searchable) {
      return TextField(
        controller: controller,
        enabled: false,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: l10n.stopAddressLabel,
          helperText: l10n.addressFixedHelper,
          helperMaxLines: 2,
          // 칸은 흐리게(고칠 수 없음) 두되, 안내는 읽혀야 해서 다른 칸의 안내와 같은 색이다.
          helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return AddressSearch(
      controller: controller,
      label: l10n.stopAddressLabel,
      enabled: enabled,
      maxLength: StopDraft.addressMaxLength,
      onPicked: onPicked,
    );
  }
}

/// 종류 칩(숙소·음식·관광·기타).
class PlaceKindChips extends StatelessWidget {
  const PlaceKindChips({
    super.key,
    required this.kind,
    required this.onChanged,
  });

  final StopKind kind;
  final ValueChanged<StopKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.stopKindLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: 0,
          children: [
            for (final value in StopKind.values)
              ChoiceChip(
                label: Text(l10n.stopKindName(value)),
                selected: kind == value,
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

/// 설명 칸(공유하면 보임)과 메모 칸(나만 봄). 둘 사이를 [gap]만큼 띄운다.
class PlaceNotesFields extends StatelessWidget {
  const PlaceNotesFields({
    super.key,
    required this.description,
    required this.memo,
    required this.enabled,
    this.gap = AppSpace.lg,
  });

  final TextEditingController description;
  final TextEditingController memo;
  final bool enabled;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget field(TextEditingController controller, String label, String help) =>
        _NoteField(
          controller: controller,
          enabled: enabled,
          label: label,
          helper: help,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          description,
          l10n.stopDescriptionLabel,
          l10n.stopDescriptionHelper,
        ),
        SizedBox(height: gap),
        field(memo, l10n.stopMemoLabel, l10n.stopMemoHelper),
      ],
    );
  }
}

/// 설명·메모처럼 2줄 이상인 칸.
///
/// 비었을 때의 큰 이름표는 한 줄 칸(이름·주소)의 큰 이름표와 같은 높이, 곧 칸의 첫째 줄에 둔다.
class _NoteField extends StatefulWidget {
  const _NoteField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.helper,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String helper;

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  /// 칠한 칸(M3)에서 첫 글자 줄 가운데와 한 줄 칸의 큰 이름표 가운데의 차이.
  static const _restingLift = AppSpace.sm;

  /// 이름표가 작게 올라가는 시간·곡선(InputDecorator와 같다).
  static const _duration = Duration(milliseconds: 167);

  final _focus = FocusNode();
  late bool _resting = _isResting;

  bool get _isResting => !_focus.hasFocus && widget.controller.text.isEmpty;

  void _update() {
    if (_isResting != _resting) setState(() => _resting = _isResting);
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_update);
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(_NoteField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_update);
      widget.controller.addListener(_update);
      _resting = _isResting;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    focusNode: _focus,
    enabled: widget.enabled,
    minLines: 2,
    maxLines: 6,
    maxLength: StopDraft.textMaxLength,
    decoration: InputDecoration(
      label: TweenAnimationBuilder<double>(
        tween: Tween(end: _resting ? -_restingLift : 0),
        duration: _duration,
        curve: Curves.fastOutSlowIn,
        builder: (context, dy, child) =>
            Transform.translate(offset: Offset(0, dy), child: child),
        child: Text(widget.label),
      ),
      helperText: widget.helper,
      helperMaxLines: 2,
      alignLabelWithHint: true,
    ),
  );
}

/// 입력 화면 맨 아래의 버튼 줄. 버튼은 왼쪽부터 한 줄에 놓고, 폭이 모자랄 때만 다음 줄로 넘긴다.
class FormActionRow extends StatelessWidget {
  const FormActionRow({super.key, required this.children});

  final List<FormActionButton> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: children);
}

/// 입력 화면 맨 아래의 테두리 버튼(예: 지우기, 후보로 빼기). [FormActionRow]에 넣는다.
/// [busy]면 아이콘 자리에 진행 표시가 돈다. [danger]면 지우기처럼 오류 색이다.
class FormActionButton extends StatelessWidget {
  const FormActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;

  /// null이면 누를 수 없다(다른 저장을 기다리는 중).
  final VoidCallback? onPressed;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : null;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? SavingIndicator(
              label: context.l10n.saving,
              padded: false,
              color: color,
            )
          : Icon(icon),
      label: Text(label),
      style: danger
          ? OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
            )
          : null,
    );
  }
}

/// 고친 내용을 버리고 닫을지 묻는다. 버리면 true다.
Future<bool> confirmDiscardChanges(BuildContext context) async {
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

/// 지울지 묻는다([title], [message]). 지우면 true다. 지우기 버튼은 오류 색이다.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
          child: Text(context.l10n.deleteStop),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

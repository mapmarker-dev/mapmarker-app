import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/stop.dart';
import '../../../l10n/l10n.dart';
import '../stop_draft.dart';

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
    decoration: InputDecoration(labelText: context.l10n.stopNameLabel),
  );
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
          runSpacing: AppSpace.sm,
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
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: 2,
          maxLines: 6,
          maxLength: StopDraft.textMaxLength,
          decoration: InputDecoration(
            labelText: label,
            helperText: help,
            helperMaxLines: 2,
            alignLabelWithHint: true,
          ),
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

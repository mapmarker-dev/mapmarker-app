import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/form_saving.dart';
import '../../../core/widgets/saving.dart';
import '../../../l10n/l10n.dart';
import '../candidate_draft.dart';
import 'place_fields.dart';

/// 후보 입력 화면을 띄운다. 저장하면 고친 값을, 그냥 닫거나 지우면 null을 돌려준다.
///
/// 장소 입력 화면과 같은 전체 화면이고 같은 칸(이름·종류·설명·메모)을 쓴다. 일차·넣을 자리·예정 시각은 없다.
/// [onSave]로 저장되면 닫히고, 저장하지 못하면 입력한 그대로 열려 있고 화면 안에 알린다([FormSaving]).
/// [onDelete]가 있으면(고칠 때) 맨 아래에 "후보 지우기"가 있다. 확인을 받아 지우면 닫는다.
Future<CandidateDraft?> showCandidateForm(
  BuildContext context, {
  required CandidateDraft initial,
  required bool isNew,
  required Future<void> Function(CandidateDraft draft) onSave,
  Future<void> Function()? onDelete,
}) => showDialog<CandidateDraft>(
  context: context,
  useSafeArea: false,
  builder: (context) => CandidateFormDialog(
    initial: initial,
    isNew: isNew,
    onSave: onSave,
    onDelete: onDelete,
  ),
);

class CandidateFormDialog extends StatefulWidget {
  const CandidateFormDialog({
    super.key,
    required this.initial,
    required this.isNew,
    required this.onSave,
    this.onDelete,
  });

  final CandidateDraft initial;

  /// 새 후보를 저장한다. false면 있는 후보를 고친다.
  final bool isNew;

  /// 고친 값을 저장한다. 저장하지 못하면 `ApiException`을 던진다.
  final Future<void> Function(CandidateDraft draft) onSave;

  /// 후보를 지운다(확인은 이 화면이 받는다). null이면 지우기가 없다(새 후보, 샘플).
  final Future<void> Function()? onDelete;

  @override
  State<CandidateFormDialog> createState() => _CandidateFormDialogState();
}

class _CandidateFormDialogState extends State<CandidateFormDialog>
    with FormSaving {
  late CandidateDraft _draft = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late final _description = TextEditingController(
    text: widget.initial.description,
  );
  late final _memo = TextEditingController(text: widget.initial.memo);

  /// 지우는 중인지. 저장 중 표시를 저장 버튼이 아닌 지우기 버튼에 띄운다.
  bool _deleting = false;

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

  void _save() {
    final draft = _draft;
    saveAndClose(() => widget.onSave(draft), draft);
  }

  /// 확인을 받아 지운다. 고친 내용이 있어도 함께 버린다.
  Future<void> _delete(Future<void> Function() delete) async {
    final l10n = context.l10n;
    final confirmed = await confirmDelete(
      context,
      title: l10n.deleteCandidateTitle(widget.initial.name),
      message: l10n.deleteCandidateMessage,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    await saveAndClose(delete);
    if (mounted) setState(() => _deleting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final insets = MediaQuery.paddingOf(context);
    const gap = SizedBox(height: AppSpace.lg);

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
            title: Text(
              widget.isNew
                  ? l10n.candidateFormAddTitle
                  : l10n.candidateFormEditTitle,
            ),
            actions: [
              if (saving && !_deleting)
                SavingIndicator(label: l10n.saving)
              else
                TextButton(
                  onPressed: _draft.isValid && !saving ? _save : null,
                  child: Text(material.saveButtonLabel),
                ),
            ],
          ),
          body: SavingFormBody(
            saving: saving,
            error: saveError,
            insets: insets,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                insets.left + AppSpace.lg,
                AppSpace.lg,
                insets.right + AppSpace.lg,
                insets.bottom + AppSpace.xl,
              ),
              children: [
                Text(
                  l10n.candidateFormHelper,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                gap,
                PlaceNameField(
                  controller: _name,
                  enabled: !saving,
                  autofocus: widget.isNew && widget.initial.name.isEmpty,
                ),
                gap,
                PlaceKindChips(
                  kind: _draft.kind,
                  onChanged: (kind) =>
                      setState(() => _draft = _draft.copyWith(kind: kind)),
                ),
                gap,
                PlaceNotesFields(
                  description: _description,
                  memo: _memo,
                  enabled: !saving,
                ),
                if (widget.onDelete case final onDelete?) ...[
                  const SizedBox(height: AppSpace.xl),
                  FormActionButton(
                    icon: Icons.delete_outline,
                    label: l10n.candidateFormDelete,
                    onPressed: saving ? null : () => _delete(onDelete),
                    busy: _deleting,
                    danger: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

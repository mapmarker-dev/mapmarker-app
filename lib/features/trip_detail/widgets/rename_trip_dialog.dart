import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/trip.dart';
import '../../../l10n/l10n.dart';
import 'form_saving.dart';

/// 제목을 바꾸는 창. [onSave]로 저장되면 닫힌다. 저장하지 못하면 입력한 제목을 둔 채 창 안에 알린다.
class RenameTripDialog extends StatefulWidget {
  const RenameTripDialog({
    super.key,
    required this.title,
    required this.defaultTitle,
    required this.onSave,
  });

  final String title;
  final String defaultTitle;

  /// 입력한 제목을 저장한다. 저장하지 못하면 `ApiException`을 던진다.
  final Future<void> Function(String title) onSave;

  @override
  State<RenameTripDialog> createState() => _RenameTripDialogState();
}

class _RenameTripDialogState extends State<RenameTripDialog> with FormSaving {
  late final _controller = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text;
    saveAndClose(() => widget.onSave(title), title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 취소·저장은 Material이 언어별로 준다.
    final material = MaterialLocalizations.of(context);
    final error = saveError;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(l10n.renameTrip),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              enabled: !saving,
              autofocus: true,
              maxLength: Trip.titleMaxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: widget.defaultTitle,
                helperText: l10n.renameTripHelper,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpace.md),
              SaveErrorBanner(error),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: Text(material.cancelButtonLabel),
          ),
          if (saving)
            SavingIndicator(label: l10n.saving)
          else
            TextButton(onPressed: _save, child: Text(material.saveButtonLabel)),
        ],
      ),
    );
  }
}

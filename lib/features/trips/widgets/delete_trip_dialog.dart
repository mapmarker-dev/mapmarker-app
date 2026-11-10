import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/form_saving.dart';
import '../../../core/widgets/saving.dart';
import '../../../l10n/l10n.dart';

/// 여행을 지울지 묻는 창. [지우기]를 누르면 [onDelete]로 지우고, 지워지면 닫힌다.
/// 지우지 못하면 창을 열어 둔 채 그 안에 알린다.
class DeleteTripDialog extends StatefulWidget {
  const DeleteTripDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onDelete,
  });

  final String title;
  final String message;

  /// 지운다. 지우지 못하면 `ApiException`을 던진다.
  final Future<void> Function() onDelete;

  @override
  State<DeleteTripDialog> createState() => _DeleteTripDialogState();
}

class _DeleteTripDialogState extends State<DeleteTripDialog> with FormSaving {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = saveError;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            if (error != null) ...[
              const SizedBox(height: AppSpace.md),
              SaveErrorBanner(error),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          if (saving)
            SavingIndicator(label: l10n.saving)
          else
            TextButton(
              onPressed: () => saveAndClose(widget.onDelete),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.deleteStop),
            ),
        ],
      ),
    );
  }
}

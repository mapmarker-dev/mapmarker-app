import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_tokens.dart';
import 'form_saving.dart';
import 'saving.dart';

/// 지울지 묻는 창. [confirmLabel]을 누르면 [onConfirm]으로 지우고, 지워지면 닫힌다.
/// 지우지 못하면 창을 열어 둔 채 그 안에 알린다(`FormSaving`).
/// 여행 휴지통으로 옮기기·샘플 숨기기(여행 목록)와 영구 삭제(휴지통)가 함께 쓴다.
class ConfirmDeleteDialog extends StatefulWidget {
  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final String message;

  /// 지우는 버튼의 글자. 위험한 동작이라 오류 색으로 그린다.
  final String confirmLabel;

  /// 지운다. 지우지 못하면 `ApiException`을 던진다.
  final Future<void> Function() onConfirm;

  @override
  State<ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<ConfirmDeleteDialog>
    with FormSaving {
  @override
  Widget build(BuildContext context) {
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
            SavingIndicator(label: context.l10n.saving)
          else
            TextButton(
              onPressed: () => saveAndClose(widget.onConfirm),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(widget.confirmLabel),
            ),
        ],
      ),
    );
  }
}

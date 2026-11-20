import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/zoned_time.dart';
import '../../../core/widgets/form_saving.dart';
import '../../../core/widgets/saving.dart';
import '../../../data/models/stop.dart';
import '../../../l10n/l10n.dart';

/// [방문 완료]와 [방문 취소]의 확인 창. 실수로 누르지 않게 둘 다 묻는다(사용자 결정).
///
/// [onConfirm]으로 저장하고, 저장되면 닫힌다. 저장하지 못하면 창을 열어 둔 채 그 안에 알린다(`FormSaving`).
/// 방문 완료는 [at]에 기록할 시각을 장소 현지 날짜와 시각으로 보여 준다. 방문 취소는 지워질 기록을 보여 준다.
/// 방문 취소 창의 닫는 버튼은 "취소" 대신 "닫기"다([방문 취소]와 헷갈리지 않게).
class VisitDialog extends StatefulWidget {
  const VisitDialog({
    super.key,
    required this.stop,
    required this.at,
    required this.onConfirm,
  });

  final Stop stop;

  /// 방문 완료면 기록할 시각, 방문 취소면 지금 기록된 시각(없을 수 있다).
  final DateTime? at;

  /// 저장한다. 저장하지 못하면 `ApiException`을 던진다.
  final Future<void> Function() onConfirm;

  @override
  State<VisitDialog> createState() => _VisitDialogState();
}

class _VisitDialogState extends State<VisitDialog> with FormSaving {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final stop = widget.stop;
    final undo = stop.visited;
    final at = widget.at;
    final parts = at == null ? null : zonedParts(at, stop.timeZone);
    String format(LocalTime time) => material.formatTimeOfDay(
      TimeOfDay(hour: time.hour, minute: time.minute),
    );
    final message = switch ((undo, parts)) {
      (false, final parts?) => l10n.visitDoneMessage(
        parts.date.toDateTime(),
        format(parts.time),
      ),
      (true, final parts?) => l10n.visitUndoMessage(
        parts.date.toDateTime(),
        format(parts.time),
      ),
      _ => l10n.visitUndoMessageNoTime,
    };
    final error = saveError;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(
          undo
              ? l10n.visitUndoTitle(stop.name)
              : l10n.visitDoneTitle(stop.name),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (error != null) ...[
              const SizedBox(height: AppSpace.md),
              SaveErrorBanner(error),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: Text(
              undo ? material.closeButtonLabel : material.cancelButtonLabel,
            ),
          ),
          if (saving)
            SavingIndicator(label: l10n.saving)
          else
            TextButton(
              onPressed: () => saveAndClose(widget.onConfirm),
              child: Text(undo ? l10n.visitUndo : l10n.visitDone),
            ),
        ],
      ),
    );
  }
}

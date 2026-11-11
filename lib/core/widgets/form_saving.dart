import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'saving.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';

/// 입력 화면이 저장하는 동안의 상태.
///
/// 저장되기 전까지 화면을 닫지 않는다. 닫고 나서 실패하면 입력한 내용이 사라지고, 기다리는 동안 예전 값이 보여서다.
/// 저장하는 동안([saving]) 입력과 닫기를 잠그고, 실패하면 입력한 그대로 두고 [saveError]를 화면 안에 띄운다.
mixin FormSaving<T extends StatefulWidget> on State<T> {
  bool saving = false;

  /// 마지막 저장 실패 안내. 다시 저장하기 시작하면 지운다.
  String? saveError;

  /// [write]로 저장하고, 되면 [result]를 돌려주며 화면을 닫는다.
  Future<void> saveAndClose(
    Future<void> Function() write, [
    Object? result,
  ]) async {
    if (saving) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await write();
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => saveError = context.l10n.saveFailureText(error.failure));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

/// 전체 화면 입력 창의 본문. 저장하지 못했으면 맨 위에 안내를 고정해 두고(스크롤해도 보인다),
/// 저장하는 동안([saving])은 본문을 누를 수 없다.
class SavingFormBody extends StatelessWidget {
  const SavingFormBody({
    super.key,
    required this.saving,
    required this.error,
    required this.insets,
    required this.child,
  });

  final bool saving;
  final String? error;

  /// 시스템 여백. 안내를 본문과 같은 폭에 맞춘다.
  final EdgeInsets insets;

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error case final error?)
        Padding(
          padding: EdgeInsets.fromLTRB(
            insets.left + AppSpace.lg,
            AppSpace.lg,
            insets.right + AppSpace.lg,
            0,
          ),
          child: SaveErrorBanner(error),
        ),
      Expanded(
        child: AbsorbPointer(absorbing: saving, child: child),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// 제목을 바꾸는 창. 저장하면 입력한 제목을, 취소하면 null을 돌려준다.
class RenameTripDialog extends StatefulWidget {
  const RenameTripDialog({
    super.key,
    required this.title,
    required this.defaultTitle,
  });

  final String title;
  final String defaultTitle;

  @override
  State<RenameTripDialog> createState() => _RenameTripDialogState();
}

class _RenameTripDialogState extends State<RenameTripDialog> {
  late final _controller = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 취소·저장은 Material이 언어별로 준다.
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.renameTrip),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          hintText: widget.defaultTitle,
          helperText: l10n.renameTripHelper,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(onPressed: _save, child: Text(material.saveButtonLabel)),
      ],
    );
  }
}

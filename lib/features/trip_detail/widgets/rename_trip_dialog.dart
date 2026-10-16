import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: const Text('제목 바꾸기'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          hintText: widget.defaultTitle,
          helperText: '비우면 기본 제목으로 돌아갑니다.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}

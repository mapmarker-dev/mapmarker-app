import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/time/local_time.dart';
import '../../../l10n/l10n.dart';

/// 시각을 휠(오전/오후 · 시 · 분)로 고르는 아래 시트를 연다. [확인]을 누르면 고른 시각, 아니면 null이다.
///
/// 원형 시계 대신 휠로 고른다(휴대폰 알람과 같은 방식). 분은 1분 단위다.
/// [확인]을 눌러야 바뀌므로 열어 보기만 하면 저장된 시각은 그대로다.
/// [title]이 없으면 "예정 시각"이고, [initial]이 없으면 12:00에서 시작한다.
Future<LocalTime?> showTimeWheel(
  BuildContext context, {
  LocalTime? initial,
  String? title,
}) => showModalBottomSheet<LocalTime>(
  context: context,
  showDragHandle: true,
  builder: (context) => _TimeWheelSheet(
    initial: initial ?? const LocalTime(12, 0),
    title: title ?? context.l10n.stopTimeLabel,
  ),
);

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initial, required this.title});

  final LocalTime initial;
  final String title;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late LocalTime _time = widget.initial;

  /// 휠은 날짜가 붙은 시각을 다룬다. 날짜는 쓰지 않는다.
  static DateTime _onDay(LocalTime time) =>
      DateTime(2000, 1, 1, time.hour, time.minute);

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(material.cancelButtonLabel),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _time),
                  child: Text(material.okButtonLabel),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: _onDay(widget.initial),
              use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              onDateTimeChanged: (value) =>
                  setState(() => _time = LocalTime(value.hour, value.minute)),
            ),
          ),
        ],
      ),
    );
  }
}

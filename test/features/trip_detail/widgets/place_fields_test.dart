import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/place_fields.dart';
import 'package:mapmarker_app/l10n/generated/app_localizations.dart';

/// 한 줄 칸(이름)과 설명·메모 칸을 함께 띄운다.
Future<void> _pump(WidgetTester tester, {String memo = ''}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ko'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: ListView(
          children: [
            PlaceNameField(controller: TextEditingController(), enabled: true),
            PlaceNotesFields(
              description: TextEditingController(),
              memo: TextEditingController(text: memo),
              enabled: true,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// [label] 이름표 가운데가 칸 위에서 얼마나 내려와 있나.
double _labelOffset(WidgetTester tester, String label) {
  final field = find
      .ancestor(of: find.text(label), matching: find.byType(InputDecorator))
      .first;
  return tester.getCenter(find.text(label)).dy - tester.getTopLeft(field).dy;
}

void main() {
  testWidgets(
    'puts empty note labels on the first line like a one-line field',
    (tester) async {
      await _pump(tester);

      final oneLine = _labelOffset(tester, '이름');
      expect(_labelOffset(tester, '설명'), oneLine);
      expect(_labelOffset(tester, '메모'), oneLine);
    },
  );

  testWidgets('floats the label up like other fields once there is text', (
    tester,
  ) async {
    await _pump(tester, memo: '주차');
    final resting = _labelOffset(tester, '설명');

    expect(_labelOffset(tester, '메모'), lessThan(resting));

    // 비어 있어도 누르면 올라간다.
    await tester.tap(find.widgetWithText(TextField, '설명'));
    await tester.pumpAndSettle();
    expect(_labelOffset(tester, '설명'), _labelOffset(tester, '메모'));
  });
}

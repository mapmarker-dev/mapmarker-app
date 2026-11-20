import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/time_wheel_sheet.dart';

import '../../../helpers/test_app.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    LocalTime? initial,
    String? title,
    void Function(LocalTime?)? onResult,
  }) async {
    await tester.pumpWidget(
      testMaterialApp(
        GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final time = await showTimeWheel(
                      context,
                      initial: initial,
                      title: title,
                    );
                    onResult?.call(time);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows minutes one by one and keeps an off-5 time', (
    tester,
  ) async {
    LocalTime? result;
    await open(
      tester,
      initial: const LocalTime(12, 41),
      onResult: (time) => result = time,
    );

    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.minuteInterval, 1);
    expect(wheel.initialDateTime.minute, 41);

    await tester.tap(find.widgetWithText(TextButton, '확인'));
    await tester.pumpAndSettle();
    expect(result, const LocalTime(12, 41));
  });

  testWidgets('uses the planned time title unless given another', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('예정 시각'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .initialDateTime
          .hour,
      12,
    );
  });

  testWidgets('shows the given title', (tester) async {
    await open(tester, title: '방문 시각');
    expect(find.text('방문 시각'), findsOneWidget);
  });
}

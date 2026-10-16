import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';

import '../../helpers/test_app.dart';

Future<void> _rename(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('제목 바꾸기'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    title,
  );
  await tester.tap(find.text('저장'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the trip title', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
      location: Routes.trip('busan'),
    );

    expect(find.text('부산 1박 2일 봄 여행'), findsOneWidget);
  });

  testWidgets('renames the trip', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
      location: Routes.trip('busan'),
    );

    await _rename(tester, '가족 여행');

    expect(find.text('가족 여행'), findsOneWidget);

    // 목록에도 바뀐 제목이 보인다.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('가족 여행'), findsOneWidget);
  });

  testWidgets('goes back to the default title when cleared', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([
        testTrip(id: 'busan').copyWith(title: '가족 여행'),
      ]),
      location: Routes.trip('busan'),
    );

    await _rename(tester, '');

    expect(find.text('부산 1박 2일 봄 여행'), findsOneWidget);
  });

  testWidgets('keeps the title when renaming is canceled', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository([testTrip(id: 'busan')]),
      location: Routes.trip('busan'),
    );

    await tester.tap(find.byTooltip('제목 바꾸기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '가족 여행');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('부산 1박 2일 봄 여행'), findsOneWidget);
  });

  testWidgets('says so when the trip does not exist', (tester) async {
    await pumpTestApp(
      tester,
      repository: testRepository(),
      location: Routes.trip('missing'),
    );

    expect(find.text('여행을 찾을 수 없습니다.'), findsOneWidget);
  });
}

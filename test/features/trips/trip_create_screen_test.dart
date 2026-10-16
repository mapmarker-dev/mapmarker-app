import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_screen.dart';

import '../../helpers/test_app.dart';

Finder _field(String label) => find.widgetWithText(TextField, label);

String _titleText(WidgetTester tester) =>
    tester.widget<TextField>(_field('제목')).controller!.text;

VoidCallback? _createButton(WidgetTester tester) => tester
    .widget<FilledButton>(find.widgetWithText(FilledButton, '만들기'))
    .onPressed;

Future<void> _openCreate(WidgetTester tester) => pumpTestApp(
  tester,
  repository: testRepository(),
  location: Routes.tripCreate,
);

/// 테스트 화면이 작아서 버튼이 아래로 밀려나 있다.
Future<void> _tapCreate(WidgetTester tester) async {
  await tester.ensureVisible(find.text('만들기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('만들기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('creates a trip without dates', (tester) async {
    await _openCreate(tester);
    expect(_titleText(tester), '1박 2일 여행');

    await tester.enterText(_field('지역'), '부산');
    await tester.pump();

    expect(_titleText(tester), '부산 1박 2일 여행');
    // 기간이 없으면 계절을 직접 골라야 한다.
    expect(_createButton(tester), isNull);
    expect(find.text('상태: 여행 전 (날짜 미정)'), findsOneWidget);

    await tester.tap(find.byTooltip('1박 늘리기'));
    await tester.tap(find.text('봄'));
    await tester.pump();

    expect(_titleText(tester), '부산 2박 3일 봄 여행');
    expect(_createButton(tester), isNotNull);

    await _tapCreate(tester);

    // 만든 여행 화면으로 가고, 뒤로가기는 목록이다.
    expect(find.byType(TripDetailScreen), findsOneWidget);
    expect(find.text('부산 2박 3일 봄 여행'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('부산 2박 3일 봄 여행'), findsOneWidget);
    expect(find.text('날짜 미정 · 2박 3일'), findsOneWidget);
    expect(find.text('여행 전'), findsOneWidget);
  });

  testWidgets('fills length, season and phase from the dates', (tester) async {
    await _openCreate(tester);
    await tester.enterText(_field('지역'), '제주');

    // 오늘은 2026-10-15다. 달력은 이번 달부터 보인다.
    await tester.tap(find.text('날짜 고르기'));
    await tester.pumpAndSettle();
    for (final label in ['15', '17', '저장']) {
      await tester.tap(find.text(label).hitTestable().first);
      await tester.pumpAndSettle();
    }

    expect(find.text('2026.10.15 – 10.17'), findsOneWidget);
    expect(find.text('2박 3일'), findsOneWidget);
    // 기간이 있으면 일정은 기간을 따른다.
    expect(find.byTooltip('1박 늘리기'), findsNothing);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '가을')).selected,
      isTrue,
    );
    expect(find.text('상태: 여행 중 (기간으로 자동)'), findsOneWidget);
    expect(_titleText(tester), '제주 2박 3일 가을 여행');

    // 기간을 지우면 일정과 계절은 그대로 두고 직접 고칠 수 있다.
    await tester.tap(find.byTooltip('날짜 지우기'));
    await tester.pump();

    expect(find.text('날짜 고르기'), findsOneWidget);
    expect(find.byTooltip('1박 늘리기'), findsOneWidget);
    expect(_titleText(tester), '제주 2박 3일 가을 여행');
    expect(find.text('상태: 여행 전 (날짜 미정)'), findsOneWidget);
  });

  testWidgets('keeps a title the user wrote', (tester) async {
    await _openCreate(tester);
    await tester.enterText(_field('지역'), '부산');
    await tester.enterText(_field('제목'), '가족 여행');
    await tester.tap(find.text('여름'));
    await tester.pump();

    expect(_titleText(tester), '가족 여행');

    await _tapCreate(tester);

    expect(find.byType(TripDetailScreen), findsOneWidget);
    expect(find.text('가족 여행'), findsOneWidget);
  });

  testWidgets('follows the inputs again after the title is cleared', (
    tester,
  ) async {
    await _openCreate(tester);
    await tester.enterText(_field('지역'), '부산');
    await tester.enterText(_field('제목'), '가족 여행');
    await tester.enterText(_field('제목'), '');
    await tester.pump();

    // 비운 칸은 그대로 두고, 기본 제목을 힌트로 보여 준다.
    expect(_titleText(tester), isEmpty);

    await tester.tap(find.text('겨울'));
    await tester.pump();

    expect(_titleText(tester), '부산 1박 2일 겨울 여행');
  });
}

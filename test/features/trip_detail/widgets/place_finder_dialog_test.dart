import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/l10n/l10n.dart' show appLocale;
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/data/addresses/address_api.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/place_finder_dialog.dart';
import 'package:mapmarker_app/l10n/generated/app_localizations.dart';

import '../../../helpers/fake_address_api.dart';

/// 찾기 화면을 여는 버튼 하나뿐인 앱. 닫힌 결과는 [results]에 담긴다.
Future<List<FoundPlace?>> _pump(WidgetTester tester, FakeAddressApi api) async {
  final results = <FoundPlace?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [addressApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: appLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                results.add(await showPlaceFinder(context, title: '찾기 시험')),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return results;
}

Finder get _field => find.byType(TextField);

/// 결과 줄. 검색 칸에도 같은 글이 있을 수 있어 줄로 찾는다.
Finder _row(String text) => find.widgetWithText(ListTile, text);

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAddressApi api;

  setUp(() {
    api = FakeAddressApi(
      result: AddressSearchResult(
        detail: '1,2층',
        addresses: [
          testAddress(),
          testAddress(
            road: '서울특별시 송파구 올림픽로 300',
            extra: null,
            jibun: '서울특별시 송파구 신천동 29',
            building: '롯데월드타워',
          ),
        ],
      ),
    );
  });

  testWidgets('shows the title and a guide before searching', (tester) async {
    await _pump(tester, api);

    expect(find.text('찾기 시험'), findsOneWidget);
    expect(find.text('지도 앱에서 복사한 주소를 붙여 넣거나 주소나 건물명을 입력하세요.'), findsOneWidget);
  });

  testWidgets('searches on submit, not on each keystroke', (tester) async {
    await _pump(tester, api);

    await _type(tester, '관악대로 472 1,2층');
    expect(api.searches, isEmpty);

    await _submit(tester);
    expect(api.searches, ['관악대로 472 1,2층']);

    await tester.tap(find.byTooltip('찾기'));
    await tester.pumpAndSettle();
    expect(api.searches, hasLength(2));
  });

  testWidgets('shows the building name, road and jibun of each result', (
    tester,
  ) async {
    await _pump(tester, api);
    await _type(tester, '관악대로 472');
    await _submit(tester);

    // 건물명이 없으면 도로명이 제목이다.
    expect(find.text('경기도 안양시 동안구 관악대로 472'), findsOneWidget);
    expect(find.text('지번 경기도 안양시 동안구 관양동 1588'), findsOneWidget);
    expect(find.text('롯데월드타워'), findsOneWidget);
    expect(find.text('서울특별시 송파구 올림픽로 300'), findsOneWidget);
  });

  testWidgets('shows x only with text and clears the text and results', (
    tester,
  ) async {
    await _pump(tester, api);
    expect(find.byTooltip('주소 지우기'), findsNothing);

    await _type(tester, '관악대로 472');
    await _submit(tester);
    expect(_row('롯데월드타워'), findsOneWidget);

    await tester.tap(find.byTooltip('주소 지우기'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_field).controller!.text, '');
    expect(_row('롯데월드타워'), findsNothing);
    expect(find.byTooltip('주소 지우기'), findsNothing);
    // 지우고 바로 다시 쓸 수 있다.
    expect(tester.widget<TextField>(_field).focusNode!.hasFocus, isTrue);
  });

  testWidgets('groups the results in one outlined box below the field', (
    tester,
  ) async {
    await _pump(tester, api);
    final box = find.byKey(const ValueKey('addressResults'));
    expect(box, findsNothing);

    await _type(tester, '관악대로 472');
    await _submit(tester);

    expect(box, findsOneWidget);
    expect(
      find.descendant(of: box, matching: find.byType(ListTile)),
      findsNWidgets(2),
    );
    final decoration =
        tester.widget<Container>(box).decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    // 상자는 칸 아래에 놓인다.
    expect(
      tester.getTopLeft(box).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(_field).dy),
    );
  });

  testWidgets('returns the full address and position of the chosen result', (
    tester,
  ) async {
    final results = await _pump(tester, api);
    await _type(tester, '관악대로 472 1,2층');
    await _submit(tester);

    await tester.tap(_row('경기도 안양시 동안구 관악대로 472'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceFinderDialog), findsNothing);
    final found = results.single!;
    expect(found.address, '경기도 안양시 동안구 관악대로 472, 1,2층 (관양동)');
    expect(found.position, const LatLng(37.4, 126.98));
    expect(api.refs, hasLength(1));
  });

  testWidgets('shows progress on the row and ignores other taps meanwhile', (
    tester,
  ) async {
    final hold = api.holdCoordinates = Completer<void>();
    final results = await _pump(tester, api);
    await _type(tester, '관악대로 472');
    await _submit(tester);

    await tester.tap(_row('경기도 안양시 동안구 관악대로 472'));
    await tester.pump();

    expect(
      find.descendant(
        of: _row('경기도 안양시 동안구 관악대로 472'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(_row('롯데월드타워'), warnIfMissed: false);
    await tester.pump();
    expect(api.refs, hasLength(1));

    hold.complete();
    await tester.pumpAndSettle();
    expect(results.single!.address, startsWith('경기도 안양시'));
  });

  testWidgets('drops a position that arrives after closing', (tester) async {
    final hold = api.holdCoordinates = Completer<void>();
    final results = await _pump(tester, api);
    await _type(tester, '관악대로 472');
    await _submit(tester);
    await tester.tap(_row('경기도 안양시 동안구 관악대로 472'));
    await tester.pump();

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    hold.complete();
    await tester.pumpAndSettle();

    expect(find.byType(PlaceFinderDialog), findsNothing);
    expect(results, [null]);
  });

  testWidgets('says so when nothing is found', (tester) async {
    api.result = const AddressSearchResult(detail: null, addresses: []);
    await _pump(tester, api);

    await _type(tester, '없는길 1');
    await _submit(tester);

    expect(find.text('찾지 못했습니다. 주소를 확인하거나 지도를 눌러 넣어 주세요.'), findsOneWidget);
  });

  testWidgets('explains a failed search and keeps the text', (tester) async {
    api.searchFailure = ApiFailure.unavailable;
    await _pump(tester, api);

    await _type(tester, '세종대로 110');
    await _submit(tester);

    expect(find.text('주소 검색이 잠시 되지 않습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(tester.widget<TextField>(_field).controller!.text, '세종대로 110');

    api.searchFailure = ApiFailure.network;
    await tester.tap(find.byTooltip('찾기'));
    await tester.pumpAndSettle();
    expect(find.text('인터넷에 연결되지 않아 찾지 못했습니다.'), findsOneWidget);
  });

  testWidgets('says so on the row when the building has no position', (
    tester,
  ) async {
    api.position = null;
    final results = await _pump(tester, api);
    await _type(tester, '관악대로 472');
    await _submit(tester);

    await tester.tap(_row('경기도 안양시 동안구 관악대로 472'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceFinderDialog), findsOneWidget);
    expect(find.text('이 주소는 위치를 찾지 못했습니다. 지도를 눌러 넣어 주세요.'), findsOneWidget);
    expect(results, isEmpty);
  });
}

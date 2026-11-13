import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/candidate_form_dialog.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/stop_form_dialog.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

/// 1일차: a. 후보: 우도.
const _udo = Candidate(
  id: 'udo',
  tripId: 'jeju',
  latitude: 33.5,
  longitude: 126.95,
  name: '우도',
  kind: StopKind.tour,
  description: '섬',
);

FlakyTripRepository _repository() => FlakyTripRepository(
  testRepository(
    [testTrip(id: 'jeju', region: '제주')],
    [testStop('a', tripId: 'jeju')],
    [_udo],
  ),
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FlakyTripRepository repository,
) => pumpTestApp(tester, repository: repository, location: Routes.trip('jeju'));

TripRoute _route(ProviderContainer container) =>
    container.read(tripRouteProvider('jeju')).value!;

Finder _inForm(Finder finder) =>
    find.descendant(of: find.byType(CandidateFormDialog), matching: finder);

Finder get _save => _inForm(find.text('저장'));

Finder get _name => _inForm(find.widgetWithText(TextField, '이름'));

Finder _inTile(String name, Finder finder) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(CandidateTile)),
  matching: finder,
);

Future<void> _pumpWhileSaving(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// "후보 목록" 보기에서 [name] 후보 줄을 누르고 연필로 후보 입력 화면을 연다.
Future<void> _openEdit(WidgetTester tester, String name) async {
  await tapChip(tester, '후보 목록');
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(_inTile(name, find.byTooltip('후보 고치기')));
  await tester.pumpAndSettle();
}

void main() {
  group('saving a place as a candidate', () {
    testWidgets('offers both on the card and saves where the map was tapped', (
      tester,
    ) async {
      final container = await _pump(tester, _repository());
      const tapped = LatLng(33.46, 126.31);

      await tapMap(tester, tapped, placeName: '협재해수욕장');

      expect(find.text('협재해수욕장'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '동선에 넣기'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, '후보로 저장'));
      await tester.pumpAndSettle();

      // 심볼 이름을 채워 두고, 일차·자리·예정 시각 칸은 없다.
      expect(find.byType(CandidateFormDialog), findsOneWidget);
      expect(find.text('후보로 저장'), findsWidgets);
      expect(tester.widget<TextField>(_name).controller!.text, '협재해수욕장');
      expect(_inForm(find.text('일차')), findsNothing);
      expect(_inForm(find.text('넣을 자리')), findsNothing);

      await tester.tap(_inForm(find.text('음식')));
      await tester.pump();
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.byType(CandidateFormDialog), findsNothing);
      final saved = _route(container).candidates.last;
      expect(saved.name, '협재해수욕장');
      expect(saved.kind, StopKind.food);
      expect(saved.position, tapped);
      // 임시 핀이 사라지고 후보 마커가 생긴다.
      final markers = mapScene(tester).markers;
      expect(markers.map((m) => m.id), isNot(contains('draft')));
      expect(markers.where((m) => m.secondary).map((m) => m.caption), [
        '우도',
        '협재해수욕장',
      ]);
      // 동선은 그대로다.
      expect(_route(container).stops.map((s) => s.id), ['a']);
    });

    testWidgets('needs a name', (tester) async {
      await _pump(tester, _repository());
      await tapMap(tester, const LatLng(33.46, 126.31));
      await tester.tap(find.widgetWithText(OutlinedButton, '후보로 저장'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextButton>(
              find.ancestor(of: _save, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(_name, '  ');
      await tester.pump();

      expect(
        tester
            .widget<TextButton>(
              find.ancestor(of: _save, matching: find.byType(TextButton)),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('says where it went when the "후보" filter is off', (
      tester,
    ) async {
      await _pump(tester, _repository());
      await tapChip(tester, '후보');
      await tapMap(tester, const LatLng(33.46, 126.31), placeName: '협재');
      await tester.tap(find.widgetWithText(OutlinedButton, '후보로 저장'));
      await tester.pumpAndSettle();
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.text('후보로 저장했습니다.'), findsOneWidget);
      // 앱이 몰래 켜지 않는다.
      expect(mapScene(tester).markers.where((m) => m.secondary), isEmpty);

      await tester.tap(find.widgetWithText(SnackBarAction, '후보 켜기'));
      await tester.pumpAndSettle();

      expect(
        mapScene(tester).markers.where((m) => m.secondary).map((m) => m.id),
        hasLength(2),
      );
    });

    testWidgets('shows the new candidate in the "후보" view', (tester) async {
      await _pump(tester, _repository());
      await tapChip(tester, '후보 목록');
      await tapMap(tester, const LatLng(33.46, 126.31), placeName: '협재');
      await tester.tap(find.widgetWithText(OutlinedButton, '후보로 저장'));
      await tester.pumpAndSettle();
      await tester.tap(_save);
      await tester.pumpAndSettle();

      final tile = tester.widget<CandidateTile>(
        find.ancestor(
          of: find.text('협재'),
          matching: find.byType(CandidateTile),
        ),
      );
      expect(tile.highlighted, isTrue);
      expect(find.text('2곳'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('keeps the form open while saving and when saving fails, '
        'then saves the same candidate again', (tester) async {
      final repository = _repository()
        ..holdWrites = Completer()
        ..failWrites = ApiFailure.network;
      final container = await _pump(tester, repository);
      await tapMap(tester, const LatLng(33.46, 126.31), placeName: '협재');
      await tester.tap(find.widgetWithText(OutlinedButton, '후보로 저장'));
      await tester.pumpAndSettle();

      await tester.tap(_save);
      await _pumpWhileSaving(tester);

      expect(_inForm(find.byType(CircularProgressIndicator)), findsOneWidget);

      repository.holdWrites!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CandidateFormDialog), findsOneWidget);
      expect(_inForm(find.text(testL10n.saveFailedNetwork)), findsOneWidget);

      repository
        ..holdWrites = null
        ..failWrites = null;
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.byType(CandidateFormDialog), findsNothing);
      expect(_route(container).candidates.map((c) => c.name), ['우도', '협재']);
    });

    testWidgets('still adds to the route from the same card', (tester) async {
      await _pump(tester, _repository());
      await tapMap(tester, const LatLng(33.46, 126.31), placeName: '협재');

      await tester.tap(find.widgetWithText(FilledButton, '동선에 넣기'));
      await tester.pumpAndSettle();

      expect(find.byType(StopFormDialog), findsOneWidget);
    });
  });

  group('editing a candidate', () {
    testWidgets('shows the pencil only on a row tapped in the list', (
      tester,
    ) async {
      await _pump(tester, _repository());
      await tapChip(tester, '1일차');

      // 지도에서 눌러 연 줄은 보려고 연 것이라 연필이 없다.
      await tapMarker(tester, 'udo');

      expect(_inTile('우도', find.byTooltip('후보 고치기')), findsNothing);

      await tester.tap(find.text('우도'));
      await tester.pumpAndSettle();

      expect(_inTile('우도', find.byTooltip('후보 고치기')), findsOneWidget);
    });

    testWidgets('saves the changes in place', (tester) async {
      final container = await _pump(tester, _repository());
      await _openEdit(tester, '우도');

      expect(find.text('후보 고치기'), findsWidgets);
      await tester.enterText(_name, '우도 한 바퀴');
      await tester.pump();
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.byType(CandidateFormDialog), findsNothing);
      expect(_route(container).candidateById('udo')!.name, '우도 한 바퀴');
      expect(_route(container).candidateById('udo')!.description, '섬');
      expect(find.text('우도 한 바퀴'), findsOneWidget);
    });

    testWidgets('deletes after asking', (tester) async {
      final container = await _pump(tester, _repository());
      await _openEdit(tester, '우도');

      final delete = _inForm(find.widgetWithText(OutlinedButton, '후보 지우기'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.text('우도 후보 지우기'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('지우기'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CandidateFormDialog), findsNothing);
      expect(_route(container).candidates, isEmpty);
      expect(find.textContaining('아직 후보가 없습니다.'), findsOneWidget);
    });

    testWidgets('keeps the candidate when deleting is cancelled', (
      tester,
    ) async {
      final container = await _pump(tester, _repository());
      await _openEdit(tester, '우도');
      final delete = _inForm(find.widgetWithText(OutlinedButton, '후보 지우기'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.byType(CandidateFormDialog), findsOneWidget);
      expect(_route(container).candidates, hasLength(1));
    });
  });
}

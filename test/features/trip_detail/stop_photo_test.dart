import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/theme/app_colors.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/photo.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/photos/photo_preparer.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/place_photo_field.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/stop_form_dialog.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/stop_photo.dart';

import '../../helpers/fake_map.dart';
import '../../helpers/fake_photos.dart';
import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

const _savedPhoto = Photo(
  id: 'photo-a',
  url: 'https://s3.test/a.jpg',
  thumbnailUrl: 'https://s3.test/a_thumb.jpg',
);

/// 1일차: a > b. [withPhoto]면 a에 사진이 있다.
FlakyTripRepository _repository({bool withPhoto = false}) {
  final a = testStop('a', tripId: 'jeju', kind: StopKind.tour);
  return FlakyTripRepository(
    testRepository(
      [testTrip(id: 'jeju', region: '제주')],
      [
        withPhoto ? a.copyWith(photo: () => _savedPhoto) : a,
        testStop('b', tripId: 'jeju', order: 1),
      ],
    ),
  );
}

/// 넓은 화면(오른쪽 패널)에서 1일차 목록을 연다.
Future<ProviderContainer> _openDayOne(
  WidgetTester tester,
  FlakyTripRepository repository, {
  FakePhotoSource? source,
  FakePhotoPreparer? preparer,
}) async {
  tester.view.physicalSize =
      const Size(1280, 800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final container = await pumpTestApp(
    tester,
    repository: repository,
    location: Routes.trip('jeju'),
    photoSource: source,
    photoPreparer: preparer,
  );
  await tapChip(tester, '1일차');
  return container;
}

Finder _inDialog<T extends Widget>(Finder finder) =>
    find.descendant(of: find.byType(T), matching: finder);

Finder _inStopTile(String id, Finder finder) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ItineraryStopTile && w.stop.id == id),
  matching: finder,
);

Finder _inPhotoField(Finder finder) =>
    find.descendant(of: find.byType(PlacePhotoField), matching: finder);

Future<void> _openStopForm(WidgetTester tester, String id) async {
  await tester.tap(find.text(id));
  await tester.pumpAndSettle();
  await tester.tap(_inStopTile(id, find.byTooltip('장소 편집')));
  await tester.pumpAndSettle();
}

/// 입력 화면 목록을 내려 [finder]가 보이게 한다(사진 칸은 메모 아래다).
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: _inDialog<StopFormDialog>(find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapInForm(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _save => _inDialog<StopFormDialog>(find.text('저장'));

Stop _stop(ProviderContainer container, String id) =>
    container.read(tripRouteProvider('jeju')).value!.stopById(id)!;

void main() {
  group('장소 입력 화면에서', () {
    testWidgets('사진을 고르면 줄인 썸네일이 보이고, 저장하면 장소 줄에 썸네일이 생긴다', (tester) async {
      final repository = _repository();
      final preparer = FakePhotoPreparer();
      final container = await _openDayOne(
        tester,
        repository,
        preparer: preparer,
      );
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));

      expect(_inPhotoField(find.byType(Image)), findsOneWidget);
      expect(_inPhotoField(find.text('바꾸기')), findsOneWidget);
      expect(_inPhotoField(find.text('지우기')), findsOneWidget);

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.byType(StopFormDialog), findsNothing);
      expect(_stop(container, 'a').photo?.id, preparer.prepared.single.id);
      expect(_inStopTile('a', find.byType(StopPhotoThumbnail)), findsOneWidget);
      expect(_inStopTile('b', find.byType(StopPhotoThumbnail)), findsNothing);
    });

    testWidgets('고르지 않고 닫으면 그대로다', (tester) async {
      final source = FakePhotoSource()..next = null;
      await _openDayOne(tester, _repository(), source: source);
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));

      expect(source.picks, 1);
      expect(_inPhotoField(find.text('사진 넣기')), findsOneWidget);
    });

    testWidgets('읽지 못하는 사진이면 칸 아래에 알리고 사진은 그대로다', (tester) async {
      final preparer = FakePhotoPreparer()
        ..error = const PhotoPrepareException('형식');
      await _openDayOne(tester, _repository(), preparer: preparer);
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));

      expect(
        _inPhotoField(find.text(testL10n.placePhotoReadFailed)),
        findsOneWidget,
      );
      expect(_inPhotoField(find.text('사진 넣기')), findsOneWidget);
    });

    testWidgets('있던 사진을 지우고 저장하면 사진이 없어진다', (tester) async {
      final container = await _openDayOne(tester, _repository(withPhoto: true));
      expect(_inStopTile('a', find.byType(StopPhotoThumbnail)), findsOneWidget);
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('지우기')));
      expect(_inPhotoField(find.text('사진 넣기')), findsOneWidget);
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_stop(container, 'a').photo, isNull);
      expect(_inStopTile('a', find.byType(StopPhotoThumbnail)), findsNothing);
    });

    testWidgets('있던 사진을 바꾸면 새 사진이 된다', (tester) async {
      final preparer = FakePhotoPreparer();
      final container = await _openDayOne(
        tester,
        _repository(withPhoto: true),
        preparer: preparer,
      );
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('바꾸기')));
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_stop(container, 'a').photo?.id, preparer.prepared.single.id);
    });

    testWidgets('사진만 저장하지 못하면 입력 화면에서 알리고, 다시 저장하면 사진만 다시 보낸다', (tester) async {
      final repository = _repository()..failPhotos = ApiFailure.network;
      final preparer = FakePhotoPreparer();
      final container = await _openDayOne(
        tester,
        repository,
        preparer: preparer,
      );
      await _openStopForm(tester, 'a');
      await tester.enterText(
        _inDialog<StopFormDialog>(find.widgetWithText(TextField, '이름')),
        '성산',
      );
      await tester.pump();
      await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.byType(StopFormDialog), findsOneWidget);
      expect(
        _inDialog<StopFormDialog>(find.text(testL10n.photoSaveFailed)),
        findsOneWidget,
      );
      // 장소는 저장됐다.
      expect(_stop(container, 'a').name, '성산');
      expect(_stop(container, 'a').photo, isNull);

      repository.failPhotos = null;
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.byType(StopFormDialog), findsNothing);
      expect(_stop(container, 'a').photo?.id, preparer.prepared.single.id);
    });

    testWidgets('사진이 있는 장소를 지울 때 사진도 사라진다고 알린다', (tester) async {
      await _openDayOne(tester, _repository(withPhoto: true));
      await _openStopForm(tester, 'a');

      await _tapInForm(
        tester,
        _inDialog<StopFormDialog>(
          find.widgetWithText(OutlinedButton, '장소 지우기'),
        ),
      );

      expect(
        _inDialog<AlertDialog>(find.text(testL10n.deleteStopMessageWithPhoto)),
        findsOneWidget,
      );
      // 사라질 사진을 썸네일로 보여 준다.
      expect(
        _inDialog<AlertDialog>(find.byType(LostPhotoLine)),
        findsOneWidget,
      );
    });

    testWidgets('사진이 있는 장소를 후보로 빼면 먼저 묻고 사진이 사라진다', (tester) async {
      final container = await _openDayOne(tester, _repository(withPhoto: true));
      await _openStopForm(tester, 'a');

      await _tapInForm(
        tester,
        _inDialog<StopFormDialog>(
          find.widgetWithText(OutlinedButton, '후보로 빼기'),
        ),
      );

      expect(
        _inDialog<AlertDialog>(find.text(testL10n.lostStopPhoto)),
        findsOneWidget,
      );
      await tester.tap(
        _inDialog<AlertDialog>(find.text(testL10n.demoteStopConfirm)),
      );
      await tester.pumpAndSettle();

      final route = container.read(tripRouteProvider('jeju')).value!;
      expect(route.stopById('a'), isNull);
      expect(route.candidateById('a'), isNotNull);
    });
  });

  testWidgets('지도에 넣은 새 장소도 사진과 함께 저장하고, 사진만 실패하면 다시 저장할 때 장소를 또 넣지 않는다', (
    tester,
  ) async {
    final repository = _repository()..failPhotos = ApiFailure.unavailable;
    final preparer = FakePhotoPreparer();
    final container = await _openDayOne(tester, repository, preparer: preparer);
    await tapMap(tester, const LatLng(35.2, 129.2), placeName: '오름');
    await tester.tap(find.widgetWithText(FilledButton, '동선에 넣기'));
    await tester.pumpAndSettle();
    await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));

    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(
      _inDialog<StopFormDialog>(find.text(testL10n.photoSaveFailed)),
      findsOneWidget,
    );

    repository.failPhotos = null;
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(find.byType(StopFormDialog), findsNothing);
    final stops = container.read(tripRouteProvider('jeju')).value!.stops;
    final added = stops.where((s) => s.name == '오름').toList();
    expect(added, hasLength(1));
    expect(added.single.photo?.id, preparer.prepared.single.id);
  });

  testWidgets('사진이 있는 장소는 지도에 사진 마커로 그린다', (tester) async {
    await _openDayOne(tester, _repository(withPhoto: true));

    final markers = {
      for (final marker in mapScene(tester).markers) marker.id: marker,
    };
    expect(markers['a']!.look.photo, isNotNull);
    expect(markers['a']!.look.label, '1');
    // 테두리는 일차 색보다 조금 어둡다(선과 붙어 보이지 않게).
    final colors = AppColors.light(AppTheme.light().colorScheme);
    expect(markers['a']!.look.photoFrame, colors.routePhotoFrame(1));
    expect(markers['a']!.look.photoFrame, isNot(colors.routeDay(1).background));
    expect(markers['b']!.look.photo, isNull);
  });

  testWidgets('장소 줄의 썸네일을 누르면 사진을 크게 본다', (tester) async {
    await _openDayOne(tester, _repository(withPhoto: true));

    await tester.tap(_inStopTile('a', find.byType(StopPhotoThumbnail)));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(_inDialog<Dialog>(find.byTooltip('닫기')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}

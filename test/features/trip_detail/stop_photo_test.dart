import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/theme/app_colors.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/photo.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/photos/photo_images.dart';
import 'package:mapmarker_app/data/photos/photo_preparer.dart';
import 'package:mapmarker_app/data/photos/photo_upload.dart';
import 'package:mapmarker_app/features/trip_detail/trip_detail_controller.dart';
import 'package:mapmarker_app/l10n/l10n.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/itinerary_tiles.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/photo_position_screen.dart';
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

Finder _inPosition(Finder finder) =>
    find.descendant(of: find.byType(PhotoPositionView), matching: finder);

/// [finder](사진 넣기, 바꾸기)를 눌러 사진을 고르고, "사진 위치" 화면에서 그대로 [확인]한다.
Future<void> _pickPhoto(WidgetTester tester, Finder finder) async {
  await _tapInForm(tester, finder);
  expect(find.byType(PhotoPositionView), findsOneWidget);
  await tester.tap(_inPosition(find.text('확인')));
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

      await _pickPhoto(tester, _inPhotoField(find.text('사진 넣기')));

      expect(_inPhotoField(find.byType(Image)), findsOneWidget);
      expect(_inPhotoField(find.text('바꾸기')), findsOneWidget);
      expect(_inPhotoField(find.text('지우기')), findsOneWidget);

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(find.byType(StopFormDialog), findsNothing);
      expect(_stop(container, 'a').photo, isNotNull);
      expect(preparer.areas, hasLength(1));
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

      await _pickPhoto(tester, _inPhotoField(find.text('바꾸기')));
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(_stop(container, 'a').photo?.id, isNot(_savedPhoto.id));
      expect(_stop(container, 'a').photo, isNotNull);
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
      await _pickPhoto(tester, _inPhotoField(find.text('사진 넣기')));

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
      expect(_stop(container, 'a').photo, isNotNull);
    });

    testWidgets('사진을 고르면 사진 위치 화면이 가운데 정사각형으로 열리고, 그 자리로 썸네일을 만든다', (
      tester,
    ) async {
      // 400×300 가로 사진: 짧은 변(높이)에 맞춘 정사각형은 폭의 3/4이고 가운데다.
      final preparer = FakePhotoPreparer();
      await _openDayOne(tester, _repository(), preparer: preparer);
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));
      expect(_inPosition(find.text('사진 위치')), findsOneWidget);
      await tester.tap(_inPosition(find.text('확인')));
      await tester.pumpAndSettle();

      final area = preparer.areas.single;
      expect(area.left, closeTo(0.125, 1e-6));
      expect(area.top, closeTo(0, 1e-6));
      expect(area.width, closeTo(0.75, 1e-6));
      expect(area.height, closeTo(1, 1e-6));
    });

    testWidgets('사진 위치 화면에서 사진을 끌면 정사각형이 따라 움직이고, 사진 밖으로는 못 나간다', (
      tester,
    ) async {
      final preparer = FakePhotoPreparer();
      await _openDayOne(tester, _repository(), preparer: preparer);
      await _openStopForm(tester, 'a');
      await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));

      // 사진을 왼쪽으로 조금 끌면 오른쪽 부분이 보인다.
      await tester.drag(find.byType(PhotoPositionView), const Offset(-40, 0));
      await tester.pumpAndSettle();
      await tester.tap(_inPosition(find.text('확인')));
      await tester.pumpAndSettle();
      expect(preparer.areas.last.left, greaterThan(0.125));

      // 다시 골라 끝까지 끌어도 사진 오른쪽 끝에서 멈춘다.
      await _tapInForm(tester, _inPhotoField(find.text('위치 바꾸기')));
      await tester.drag(find.byType(PhotoPositionView), const Offset(-2000, 0));
      await tester.pumpAndSettle();
      await tester.tap(_inPosition(find.text('확인')));
      await tester.pumpAndSettle();
      expect(preparer.areas.last.right, closeTo(1, 1e-6));
    });

    testWidgets('사진 위치 화면을 닫으면 사진을 고르지 않은 것이다', (tester) async {
      final preparer = FakePhotoPreparer();
      await _openDayOne(tester, _repository(), preparer: preparer);
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('사진 넣기')));
      await tester.tap(_inPosition(find.byTooltip('닫기')));
      await tester.pumpAndSettle();

      expect(preparer.areas, isEmpty);
      expect(_inPhotoField(find.text('사진 넣기')), findsOneWidget);
    });

    testWidgets('저장된 사진의 위치를 바꾸면 원본을 받아 새 썸네일의 사진으로 저장한다', (tester) async {
      final preparer = FakePhotoPreparer();
      final container = await _openDayOne(
        tester,
        _repository(withPhoto: true),
        preparer: preparer,
      );
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('위치 바꾸기')));
      await tester.tap(_inPosition(find.text('확인')));
      await tester.pumpAndSettle();
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(preparer.measured, hasLength(1));
      final photo = _stop(container, 'a').photo;
      expect(photo, isNotNull);
      expect(photo!.id, isNot(_savedPhoto.id));
    });

    testWidgets('저장된 사진의 원본을 받지 못하면 칸 아래에 알린다', (tester) async {
      tester.view.physicalSize =
          const Size(1280, 800) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await pumpTestApp(
        tester,
        repository: _repository(withPhoto: true),
        location: Routes.trip('jeju'),
        photoImages: PhotoImages((_) async => throw Exception('연결 끊김')),
      );
      await tapChip(tester, '1일차');
      await _openStopForm(tester, 'a');

      await _tapInForm(tester, _inPhotoField(find.text('위치 바꾸기')));

      expect(find.byType(PhotoPositionView), findsNothing);
      expect(
        _inPhotoField(find.text(testL10n.placePhotoFetchFailed)),
        findsOneWidget,
      );
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
    await _pickPhoto(tester, _inPhotoField(find.text('사진 넣기')));

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
    expect(added.single.photo, isNotNull);
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

  group('지도에서 사진 방향을', () {
    MapMarker markerA(WidgetTester tester) =>
        mapScene(tester).markers.singleWhere((m) => m.id == 'a');

    PhotoSide savedSide(ProviderContainer container) => container
        .read(tripRouteProvider('jeju'))
        .value!
        .stopById('a')!
        .photoSide;

    testWidgets('사진 있는 장소 줄을 펼치면 화살표가 뜨고, 고른 방향을 저장한다', (tester) async {
      final container = await _openDayOne(tester, _repository(withPhoto: true));
      expect(mapScene(tester).photoSidePicker, isNull);

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      final picker = mapScene(tester).photoSidePicker!;
      expect(picker.id, 'a');
      expect(picker.side, PhotoSide.up);
      expect(markerA(tester).look.photoSide, PhotoSide.up);

      await pickPhotoSide(tester, PhotoSide.down);

      expect(savedSide(container), PhotoSide.down);
      expect(markerA(tester).look.photoSide, PhotoSide.down);
      expect(markerA(tester).pending, isFalse);
      // 고르면 화살표가 사라져 지도를 가리지 않는다. 그 마커를 다시 누르면 다시 뜬다.
      expect(mapScene(tester).photoSidePicker, isNull);

      await tapMarker(tester, 'a');

      expect(mapScene(tester).photoSidePicker!.side, PhotoSide.down);
    });

    testWidgets('고른 뒤 줄을 접었다 펴도 화살표가 다시 뜬다', (tester) async {
      await _openDayOne(tester, _repository(withPhoto: true));
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      await pickPhotoSide(tester, PhotoSide.right);

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(mapScene(tester).photoSidePicker, isNull);
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      expect(mapScene(tester).photoSidePicker!.side, PhotoSide.right);
    });

    testWidgets('사진 없는 장소 줄과 전체 보기에는 화살표가 없다', (tester) async {
      await _openDayOne(tester, _repository(withPhoto: true));

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(mapScene(tester).photoSidePicker, isNull);

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(mapScene(tester).photoSidePicker, isNotNull);

      await tapChip(tester, '전체');
      expect(mapScene(tester).photoSidePicker, isNull);
    });

    testWidgets('저장하는 동안은 흐리게 두고, 저장하지 못하면 알리고 원래 방향으로 돌아간다', (tester) async {
      final repository = _repository(withPhoto: true);
      final container = await _openDayOne(tester, repository);
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      final hold = Completer<void>();
      repository.holdWrites = hold;

      await pickPhotoSide(tester, PhotoSide.left);

      // 새 방향을 흐리게 보여 주고, 저장될 때까지 다시 고를 수 없다.
      expect(markerA(tester).look.photoSide, PhotoSide.left);
      expect(markerA(tester).pending, isTrue);
      expect(mapScene(tester).photoSidePicker, isNull);

      repository.failWrites = ApiFailure.network;
      hold.complete();
      await tester.pumpAndSettle();

      expect(
        find.text(testL10n.saveFailureText(ApiFailure.network)),
        findsOneWidget,
      );
      expect(savedSide(container), PhotoSide.up);
      expect(markerA(tester).look.photoSide, PhotoSide.up);
      expect(markerA(tester).pending, isFalse);
      // 바뀌지 않았으니 화살표를 다시 띄워 다시 고르게 한다.
      expect(mapScene(tester).photoSidePicker!.side, PhotoSide.up);
    });

    testWidgets('연박한 숙소는 어느 밤에서나 같은 사진을 보이고, 어느 일차에서 바꿔도 함께 바뀐다', (
      tester,
    ) async {
      // 1일차와 2일차에 같은 숙소. 사진과 방향은 2일차 밤에만 있다.
      final repository = FlakyTripRepository(
        testRepository(
          [testTrip(id: 'jeju', region: '제주', nights: 2)],
          [
            testStop('a', tripId: 'jeju'),
            testLodging('hotel1', tripId: 'jeju', order: 1),
            testStop('b', tripId: 'jeju', day: 2),
            testLodging(
              'hotel2',
              tripId: 'jeju',
              day: 2,
              order: 1,
            ).copyWith(photo: () => _savedPhoto),
          ],
        ),
      );
      final container = await _openDayOne(tester, repository);

      // 1일차 지도와 줄에도 2일차 밤의 사진이 보인다.
      MapMarker hotel() =>
          mapScene(tester).markers.singleWhere((m) => m.id == 'hotel1');
      expect(hotel().look.photo, isNotNull);
      expect(
        _inStopTile('hotel1', find.byType(StopPhotoImage)),
        findsOneWidget,
      );

      // 1일차 줄에서 바꾸면 사진 주인(2일차 밤)의 방향이 바뀐다.
      await tester.tap(find.text('hotel1'));
      await tester.pumpAndSettle();
      expect(mapScene(tester).photoSidePicker!.id, 'hotel2');
      await pickPhotoSide(tester, PhotoSide.down);

      expect(
        container
            .read(tripRouteProvider('jeju'))
            .value!
            .stopById('hotel2')!
            .photoSide,
        PhotoSide.down,
      );
      expect(hotel().look.photoSide, PhotoSide.down);
    });

    testWidgets('같은 자리 사진은 하나로 맞춘다: 어느 밤에서 넣어도 주인 장소에, 지우면 모두 지운다', (
      tester,
    ) async {
      // 이 규칙 전에 두 밤에 따로 넣은 사진. 보이는 것은 먼저 오는 밤(1일차)의 사진이다.
      const other = Photo(id: 'photo-b', url: 'u', thumbnailUrl: 't');
      final repository = FlakyTripRepository(
        testRepository(
          [testTrip(id: 'jeju', region: '제주', nights: 1)],
          [
            testLodging(
              'hotel1',
              tripId: 'jeju',
            ).copyWith(photo: () => _savedPhoto),
            testLodging(
              'hotel2',
              tripId: 'jeju',
              day: 2,
            ).copyWith(photo: () => other),
          ],
        ),
      );
      final container = await _openDayOne(tester, repository);
      final controller = container.read(tripDetailProvider('jeju').notifier);
      Photo? photoOf(String id) =>
          container.read(tripRouteProvider('jeju')).value!.stopById(id)!.photo;

      await controller.setStopPhoto(
        'hotel2',
        PreparedPhoto(
          id: 'photo-new',
          original: Uint8List(1),
          originalWidth: 1,
          originalHeight: 1,
          thumbnail: Uint8List(1),
        ),
      );
      await tester.pumpAndSettle();

      expect(photoOf('hotel1')?.id, 'photo-new');
      expect(photoOf('hotel2'), isNull);

      await controller.deleteStopPhoto('hotel2');
      await tester.pumpAndSettle();

      expect(photoOf('hotel1'), isNull);
      expect(photoOf('hotel2'), isNull);
    });
  });
}

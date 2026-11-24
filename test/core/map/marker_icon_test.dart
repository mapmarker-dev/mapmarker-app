import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/map/marker_icon.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/data/models/photo.dart';

const _look = MarkerLook(
  fill: Colors.orange,
  foreground: Colors.black,
  halo: Colors.white,
);

Future<void> _pump(WidgetTester tester, MarkerLook look) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Center(child: MarkerIcon(look)),
  ),
);

void main() {
  testWidgets('draws the arrow in its size', (tester) async {
    await tester.pumpWidget(
      const Center(
        child: ArrowIcon(color: Colors.orange, outline: Colors.white),
      ),
    );

    expect(tester.getSize(find.byType(ArrowIcon)), ArrowIcon.size);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draws a two-digit number with a badge in its size', (
    tester,
  ) async {
    await _pump(
      tester,
      const MarkerLook(
        fill: Colors.orange,
        foreground: Colors.black,
        halo: Colors.white,
        label: '12',
        badge: Icons.restaurant,
      ),
    );

    expect(tester.getSize(find.byType(MarkerIcon)), MarkerIcon.size);
    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draws a small marker in its smaller size', (tester) async {
    await _pump(
      tester,
      const MarkerLook(
        fill: Colors.white,
        foreground: Colors.grey,
        halo: Colors.white,
        ring: Colors.grey,
        icon: Icons.place,
        small: true,
      ),
    );

    expect(tester.getSize(find.byType(MarkerIcon)), MarkerIcon.smallSize);
    expect(find.byIcon(Icons.place), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draws an icon instead of a number', (tester) async {
    await _pump(
      tester,
      const MarkerLook(
        fill: Colors.indigo,
        foreground: Colors.white,
        halo: Colors.white,
        icon: Icons.bed,
      ),
    );

    expect(find.byIcon(Icons.bed), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  test('tells looks apart for the icon cache', () {
    expect(
      _look,
      const MarkerLook(
        fill: Colors.orange,
        foreground: Colors.black,
        halo: Colors.white,
      ),
    );
    expect(
      _look ==
          const MarkerLook(
            fill: Colors.orange,
            foreground: Colors.black,
            halo: Colors.white,
            label: '1',
          ),
      isFalse,
    );
  });

  group('photo sides', () {
    final photo = _look.withPhoto(const AssetImage('missing.png'));

    test('put the tail tip on the place and keep the photo on its side', () {
      MarkerLook on(PhotoSide side) =>
          _look.withPhoto(const AssetImage('missing.png'), side: side);

      expect(MarkerIcon.anchorOf(on(PhotoSide.up)), const Offset(0.5, 1));
      expect(MarkerIcon.anchorOf(on(PhotoSide.down)), const Offset(0.5, 0));
      expect(MarkerIcon.anchorOf(on(PhotoSide.left)), const Offset(1, 0.5));
      expect(MarkerIcon.anchorOf(on(PhotoSide.right)), const Offset(0, 0.5));
      // 위아래는 세로로, 왼쪽 오른쪽은 가로로 길다. 사진 쪽으로 뻗는 길이는 같다.
      final up = MarkerIcon.sizeOf(on(PhotoSide.up));
      final left = MarkerIcon.sizeOf(on(PhotoSide.left));
      expect(left, Size(up.height, up.width));
      expect(up.height, MarkerIcon.photoReach);
      expect(photo.photoSide, PhotoSide.up);
      expect(on(PhotoSide.down), isNot(on(PhotoSide.up)));
    });

    for (final side in PhotoSide.values) {
      testWidgets('draws a ${side.name} photo marker in its size', (
        tester,
      ) async {
        final look = MarkerLook(
          fill: Colors.orange,
          foreground: Colors.black,
          halo: Colors.white,
          label: '12',
          photo: const AssetImage('missing.png'),
          photoSide: side,
        );

        await _pump(tester, look);
        // 사진은 테스트에서 받지 못해도 된다. 모양과 크기만 본다.
        tester.takeException();

        expect(
          tester.getSize(find.byType(MarkerIcon)),
          MarkerIcon.sizeOf(look),
        );
        expect(find.text('12'), findsOneWidget);
      });
    }

    testWidgets('draws four arrows around the place with the side ahead', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PhotoSideArrows(
              side: PhotoSide.down,
              color: Colors.orange,
              outline: Colors.white,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(PhotoSideArrows)),
        PhotoSideArrows.size,
      );
      expect(find.byType(Icon), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      // 지금 방향의 화살표는 사진 너머, 나머지는 장소 가까이에 있다.
      final ahead = PhotoSideArrows.offsetOf(PhotoSide.down, PhotoSide.down);
      final near = PhotoSideArrows.offsetOf(PhotoSide.up, PhotoSide.down);
      expect(ahead.dy, greaterThan(MarkerIcon.photoReach));
      expect(near.distance, lessThan(MarkerIcon.photoReach));
      // 그림 안에 화살표가 모두 들어간다.
      for (final side in PhotoSide.values) {
        final offset = PhotoSideArrows.offsetOf(side, PhotoSide.down);
        expect(
          offset.distance + PhotoSideArrows.arrow / 2,
          lessThanOrEqualTo(PhotoSideArrows.size.width / 2),
        );
      }
    });
  });
}

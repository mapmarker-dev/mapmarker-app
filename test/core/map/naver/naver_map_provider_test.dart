import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/map/naver/naver_map_provider.dart';

// SDK는 오버레이를 메시지(payload)로 바꿔 네이티브 지도에 보낸다. 바꿀 수 없는 값이 있으면
// 그 묶음의 오버레이가 모두 빠지고 지도에는 아무것도 안 보인다(로그에만 남는다).
// 실기기 없이 이것을 막으려고, 앱이 만든 오버레이를 메시지로 바꿔 본다.

const _line = MapLine(
  id: 'segment',
  points: [LatLng(33.50, 126.49), LatLng(33.51, 126.52)],
  color: Colors.orange,
  outline: Colors.white,
);

void main() {
  test('sends paths the SDK can read', () {
    final path = naverPathOf(_line)!;

    final payload = path.payload;

    expect(
      payload['coords'],
      isA<List<Object?>>().having((c) => c.length, 'length', 2),
    );
  });

  test('skips lines without length', () {
    expect(
      naverPathOf(
        const MapLine(
          id: 'same place',
          points: [LatLng(33.5, 126.5), LatLng(33.5, 126.5)],
          color: Colors.orange,
          outline: Colors.white,
        ),
      ),
      isNull,
    );
  });

  test('sends markers the SDK can read', () {
    final marker = naverMarkerOf(
      const MapMarker(
        id: 'stop',
        position: LatLng(33.5, 126.5),
        caption: '용두암',
        look: MarkerLook(
          fill: Colors.orange,
          foreground: Colors.black,
          halo: Colors.white,
          label: '1',
          badge: Icons.photo_camera,
        ),
      ),
      // 그림은 실기기에서만 만들 수 있다.
      icon: null,
      captionColor: Colors.black,
    );

    expect(() => marker.payload, returnsNormally);
  });

  test('sends arrows the SDK can read, turned flat on the map', () {
    final arrow = naverArrowOf(
      const MapArrow(
        id: 'segment',
        position: LatLng(33.5, 126.5),
        bearing: 135,
        color: Colors.orange,
        outline: Colors.white,
        minZoom: 13.3,
      ),
      // 그림은 실기기에서만 만들 수 있다.
      icon: null,
    );

    final payload = arrow.payload;

    expect(payload['angle'], 135);
    expect(payload['isFlat'], isTrue);
    expect(payload['minZoom'], 13.3);
    // 선보다 위, 장소 마커보다 아래.
    expect(payload['globalZIndex'], inExclusiveRange(-100000, 200000));
    expect(arrow.info.id, isNot('segment'));
  });

  test('listens to taps on markers and lines', () {
    final marker = naverMarkerOf(
      const MapMarker(
        id: 'stop',
        position: LatLng(33.5, 126.5),
        caption: '용두암',
        look: MarkerLook(
          fill: Colors.orange,
          foreground: Colors.black,
          halo: Colors.white,
          label: '1',
        ),
      ),
      icon: null,
      captionColor: Colors.black,
      onTap: () {},
    );
    final path = naverPathOf(_line, onTap: () {})!;

    // 네이티브 지도는 이 값이 있어야 탭을 앱에 알린다.
    expect(marker.payload['hasOnTapListener'], isTrue);
    expect(path.payload['hasOnTapListener'], isTrue);
    expect(
      naverPathOf(_line)!.payload['hasOnTapListener'],
      isFalse,
      reason: '누를 일이 없는 선은 지도 탭을 가로채지 않는다',
    );
  });

  test('reads place names written on several lines as one', () {
    expect(naverPlaceNameOf('제주국제공항\n국내선'), '제주국제공항 국내선');
    expect(naverPlaceNameOf('  성산일출봉 '), '성산일출봉');
    expect(naverPlaceNameOf(' \n'), isNull);
  });

  test('sends camera fits the SDK can read', () {
    final bounds = cameraBoundsFor(_line.points)!;

    for (final animate in [true, false]) {
      expect(
        () => naverFitOf(bounds, animate: animate).payload,
        returnsNormally,
      );
    }
  });

  group('patterned lines', () {
    MapLine styled(MapLineStyle style) => MapLine(
      id: 'segment',
      points: _line.points,
      color: Colors.orange,
      outline: Colors.white,
      style: style,
    );

    test('keep solid lines as one outlined path', () {
      final overlays = naverLinesOf(_line);

      expect(overlays, hasLength(1));
      expect(overlays.single, isA<NPathOverlay>());
    });

    test('draw dashes and dots as an outline line under the colored line', () {
      for (final style in [MapLineStyle.dashed, MapLineStyle.dotted]) {
        final [halo, line] = naverPatternLinesOf(styled(style));
        final haloPayload = halo.payload;
        final linePayload = line.payload;

        expect(line.info.id, 'segment', reason: '$style');
        expect(halo.info.id, isNot('segment'), reason: '$style');
        expect(linePayload['color'], isNot(haloPayload['color']));
        expect(
          haloPayload['width'] as double,
          greaterThan(linePayload['width'] as double),
        );
        // 테두리 선이 아래에 깔린다. 선 높이는 경로선과 같아서 화살표·마커보다 아래다.
        expect(
          haloPayload['globalZIndex'] as int,
          lessThan(linePayload['globalZIndex'] as int),
        );
        expect(linePayload['globalZIndex'], lessThan(100000));
        // SDK는 List만 메시지로 바꾼다. 두 선의 무늬가 같아야 맞물린다.
        expect(linePayload['coords'], isA<List<Object?>>());
        expect(linePayload['pattern'], isA<List<Object?>>());
        expect(linePayload['pattern'], isNotEmpty);
        expect(haloPayload['pattern'], linePayload['pattern']);
      }
    });

    test('round the dots but cut the dashes square', () {
      final [_, dots] = naverPatternLinesOf(styled(MapLineStyle.dotted));
      final [_, dashes] = naverPatternLinesOf(styled(MapLineStyle.dashed));

      expect(dots.lineCap, NLineCap.round);
      expect(dashes.lineCap, NLineCap.butt);
      expect(dots.pattern, isNot(dashes.pattern));
    });

    test('listen to taps on both lines', () {
      final lines = naverPatternLinesOf(
        styled(MapLineStyle.dashed),
        onTap: () {},
      );

      for (final line in lines) {
        expect(line.payload['hasOnTapListener'], isTrue);
      }
    });

    test('skip lines without length', () {
      expect(
        naverLinesOf(
          const MapLine(
            id: 'same place',
            points: [LatLng(33.5, 126.5), LatLng(33.5, 126.5)],
            color: Colors.orange,
            outline: Colors.white,
            style: MapLineStyle.dotted,
          ),
        ),
        isEmpty,
      );
    });
  });

  test('sends line icons the SDK can read, standing above arrows', () {
    final marker = naverLineIconOf(
      const MapLineIcon(
        id: 'segment',
        position: LatLng(33.5, 126.5),
        icon: Icons.subway,
        background: Colors.white,
        border: Colors.orange,
        foreground: Colors.brown,
        minZoom: 14.3,
      ),
      // 그림은 실기기에서만 만들 수 있다.
      icon: null,
      onTap: () {},
    );

    final payload = marker.payload;

    expect(payload['minZoom'], 14.3);
    expect(payload['isFlat'], isFalse);
    // 화살표(100000)보다 위, 장소 마커(200000)보다 아래.
    expect(payload['globalZIndex'], inExclusiveRange(100000, 200000));
    expect(payload['hasOnTapListener'], isTrue);
    expect(marker.info.id, isNot('segment'));
  });
}

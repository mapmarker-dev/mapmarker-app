import 'package:flutter/material.dart';
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

  test('sends camera fits the SDK can read', () {
    final bounds = cameraBoundsFor(_line.points)!;

    for (final animate in [true, false]) {
      expect(
        () => naverFitOf(bounds, animate: animate).payload,
        returnsNormally,
      );
    }
  });
}

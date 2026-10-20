import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/external_map.dart';
import 'package:mapmarker_app/core/map/geo.dart';

void main() {
  group('naverMapSearchUri', () {
    test('searches the name around the place', () {
      final uri = naverMapSearchUri('성산일출봉', const LatLng(33.4590, 126.9423));

      expect(uri.scheme, 'https');
      expect(uri.host, 'map.naver.com');
      expect(uri.pathSegments, ['p', 'search', '성산일출봉']);
      // 경도가 먼저다. 쉼표는 그대로 둔다.
      expect(uri.query, 'c=126.9423000,33.4590000,15,0,0,0,dh');
      expect(
        uri.toString(),
        'https://map.naver.com/p/search/'
        '%EC%84%B1%EC%82%B0%EC%9D%BC%EC%B6%9C%EB%B4%89'
        '?c=126.9423000,33.4590000,15,0,0,0,dh',
      );
    });

    test('keeps spaces and slashes inside the name', () {
      final uri = naverMapSearchUri(' 카페 1/2 ', const LatLng(37.5, 127.0));

      expect(uri.pathSegments.last, '카페 1/2');
      expect(uri.path, endsWith('%EC%B9%B4%ED%8E%98%201%2F2'));
    });
  });
}

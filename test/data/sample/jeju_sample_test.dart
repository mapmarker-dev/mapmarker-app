import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/sample/jeju_sample.dart';

import '../../helpers/test_app.dart';

void main() {
  final sample = jejuSample(testL10n);

  String addressOf(String name) => [
    ...sample.route.stops.where((s) => s.name == name).map((s) => s.address),
    ...sample.route.candidates
        .where((c) => c.name == name)
        .map((c) => c.address),
  ].first;

  test('gives the address search result to the places it can find', () {
    expect(addressOf('제주국제공항'), '제주특별자치도 제주시 공항로 2 (용담이동)');
    expect(addressOf('오설록 티뮤지엄'), '제주특별자치도 서귀포시 안덕면 신화역사로 15');
    // 후보도 주소가 있다.
    expect(addressOf('비자림'), '제주특별자치도 제주시 구좌읍 비자숲길 55');
  });

  test('leaves the address empty where the search finds nothing', () {
    // 해변, 섬, 거리는 도로명주소 검색으로 찾지 못하고, 숙소는 이름뿐이다.
    for (final name in ['협재해수욕장', '우도', '애월 카페거리', '제주시 숙소', '서귀포 숙소']) {
      expect(addressOf(name), isEmpty, reason: name);
    }
  });

  test('keeps the address on both visits to the airport', () {
    // 첫날의 공항은 예정 시각만 바꾼 copyWith다.
    final airports = sample.route.stops.where((s) => s.name == '제주국제공항');
    expect(airports, hasLength(2));
    expect(airports.map((s) => s.address).toSet(), hasLength(1));
  });
}

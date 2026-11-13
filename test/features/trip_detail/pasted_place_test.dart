import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/features/trip_detail/pasted_place.dart';

void main() {
  test('a single line is the query with no name', () {
    expect(parsePastedPlace('  경기 안양시 동안구 관악대로 472 1,2층 '), (
      query: '경기 안양시 동안구 관악대로 472 1,2층',
      nameHint: null,
    ));
  });

  test(
    'takes the address-looking line and the first other line as the name',
    () {
      expect(
        parsePastedPlace(
          '투썸플레이스 인덕원역점\n경기 안양시 동안구 관악대로 472 1,2층\nhttps://naver.me/abc',
        ),
        (query: '경기 안양시 동안구 관악대로 472 1,2층', nameHint: '투썸플레이스 인덕원역점'),
      );
    },
  );

  test('drops link and bracket tag lines', () {
    expect(
      parsePastedPlace('[네이버 지도]\n\n동문시장\n제주특별자치도 제주시 관덕로14길 20\nnaver.me/xyz'),
      (query: '제주특별자치도 제주시 관덕로14길 20', nameHint: '동문시장'),
    );
  });

  test('finds a jibun address and a name written after it', () {
    expect(parsePastedPlace('제주 서귀포시 성산읍 성산리 1\r\n성산일출봉'), (
      query: '제주 서귀포시 성산읍 성산리 1',
      nameHint: '성산일출봉',
    ));
  });

  test('finds an address that starts with a province', () {
    expect(parsePastedPlace('롯데월드타워\n서울특별시 송파구 올림픽로 300'), (
      query: '서울특별시 송파구 올림픽로 300',
      nameHint: '롯데월드타워',
    ));
    expect(parsePastedPlace('카페\n대한민국 서울특별시 중구 세종대로 110'), (
      query: '대한민국 서울특별시 중구 세종대로 110',
      nameHint: '카페',
    ));
  });

  test('without an address-looking line, the first line is the query', () {
    expect(parsePastedPlace('롯데월드타워\n전망대'), (query: '롯데월드타워', nameHint: null));
  });

  test('a name hint longer than a name can be is dropped', () {
    expect(parsePastedPlace('${'가' * 51}\n서울 종로구 사직로 161').nameHint, isNull);
  });

  test('blank text gives an empty query', () {
    expect(parsePastedPlace(' \n https://naver.me/x \n'), (
      query: '',
      nameHint: null,
    ));
  });
}

import 'dart:async';

import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/data/addresses/address_api.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';

/// 서버 대신 답하는 주소 API. 테스트가 결과를 정하고 받은 요청을 기억한다.
class FakeAddressApi implements AddressApi {
  FakeAddressApi({
    this.result = const AddressSearchResult(detail: null, addresses: []),
    this.position = const LatLng(37.4, 126.98),
  });

  AddressSearchResult result;

  /// 좌표. null이면 그 건물의 좌표가 없다.
  LatLng? position;

  /// 정하면 검색이 이 실패로 끝난다.
  ApiFailure? searchFailure;

  /// 정하면 좌표 받기가 이 실패로 끝난다.
  ApiFailure? coordinatesFailure;

  /// 정하면 좌표 받기가 이것이 끝날 때까지 기다린다(받는 동안을 본다).
  Completer<void>? holdCoordinates;

  final searches = <String>[];
  final refs = <AddressRef>[];

  @override
  Future<AddressSearchResult> search(String text) async {
    searches.add(text);
    if (searchFailure case final failure?) throw ApiException(failure);
    return result;
  }

  @override
  Future<LatLng?> coordinates(AddressRef ref) async {
    refs.add(ref);
    await holdCoordinates?.future;
    if (coordinatesFailure case final failure?) throw ApiException(failure);
    return position;
  }
}

/// 서버 응답 모양으로 만든 주소 하나.
AddressCandidate testAddress({
  String road = '경기도 안양시 동안구 관악대로 472',
  String? extra = '(관양동)',
  String jibun = '경기도 안양시 동안구 관양동 1588',
  String? building,
}) => addressCandidateFromJson({
  'roadAddress': road,
  'roadAddressExtra': extra,
  'jibunAddress': jibun,
  'buildingName': building,
  'zipCode': '14054',
  'ref': {
    'admCd': '4117310400',
    'rnMgtSn': '411734349005',
    'udrtYn': '0',
    'buldMnnm': 472,
    'buldSlno': 0,
  },
});

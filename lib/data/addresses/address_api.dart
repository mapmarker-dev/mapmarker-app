import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/map/geo.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';

/// 주소 검색과 좌표 조회(`/v1/addresses`). 서버가 행안부 도로명주소 API를 부른다(키는 서버에만 있다).
///
/// 실패는 [ApiException]이다. 서버가 찾을 글이 없다고 하면(400) 빈 결과로 본다.
class AddressApi {
  const AddressApi(this._client);

  final ApiClient _client;

  /// 붙여 넣거나 친 [text]로 찾는다. 서버가 검색어를 다듬고 상세 주소(예: "1,2층")를 떼어 돌려준다.
  Future<AddressSearchResult> search(String text) async {
    final Object? json;
    try {
      json = await _client.get('/addresses', query: {'query': text});
    } on ApiException catch (error) {
      if (error.failure == ApiFailure.badRequest) {
        return const AddressSearchResult(detail: null, addresses: []);
      }
      rethrow;
    }
    return _read(json, _searchResultFromJson);
  }

  /// [ref] 건물의 출입구 좌표. 없으면 null이다.
  Future<LatLng?> coordinates(AddressRef ref) async {
    final Object? json;
    try {
      json = await _client.get('/addresses/coordinates', query: ref.toQuery());
    } on ApiException catch (error) {
      if (error.failure == ApiFailure.notFound) return null;
      rethrow;
    }
    return _read(json, (json) {
      final map = _map(json);
      return LatLng(_number(map, 'latitude'), _number(map, 'longitude'));
    });
  }

  T _read<T>(Object? json, T Function(Object? json) parse) {
    try {
      return parse(json);
    } on FormatException {
      throw const ApiException(ApiFailure.server);
    }
  }
}

final addressApiProvider = Provider<AddressApi>(
  (ref) => AddressApi(ref.watch(apiClientProvider)),
);

/// 주소 검색 결과.
@immutable
class AddressSearchResult {
  const AddressSearchResult({
    required this.detail,
    required this.addresses,
    this._totalCount,
  });

  /// 검색어에서 떼어 낸 상세 주소. 예: "1,2층". 없으면 null이다.
  final String? detail;

  /// 받은 주소. 서버가 앞의 10건만 준다.
  final List<AddressCandidate> addresses;

  final int? _totalCount;

  /// 행안부가 찾은 전체 개수. 서버가 주지 않으면(예전 서버) [addresses]의 길이다.
  int get totalCount => _totalCount ?? addresses.length;

  /// 받지 못한 결과가 더 있다. 검색어를 좁히라고 안내한다.
  bool get hasMore => totalCount > addresses.length;
}

/// 좌표 조회에 넘기는 건물 키. 서버가 준 값을 그대로 돌려보낸다.
@immutable
class AddressRef {
  const AddressRef(this._fields);

  final Map<String, Object?> _fields;

  Map<String, Object?> toQuery() => {
    for (final MapEntry(:key, :value) in _fields.entries) key: '$value',
  };
}

/// 찾은 주소 하나.
@immutable
class AddressCandidate {
  const AddressCandidate({
    required this.roadAddress,
    required this.roadAddressExtra,
    required this.jibunAddress,
    required this.buildingName,
    required this.ref,
  });

  /// 장소·후보 주소 칸의 최대 글자 수. 서버의 ADDRESS_MAX_LENGTH와 같다.
  static const maxLength = 200;

  /// 도로명주소(참고 항목 제외). 예: "경기도 안양시 동안구 관악대로 472".
  final String roadAddress;

  /// 참고 항목. 예: "(관양동)".
  final String? roadAddressExtra;

  final String jibunAddress;

  /// 건물명. 가게 이름과 다를 때가 많아 이름 칸에 넣지 않는다.
  final String? buildingName;

  final AddressRef ref;

  /// 주소 칸에 넣을 글: 도로명 + ", 상세" + " 참고 항목". 없는 부분은 빼고 [maxLength]로 자른다.
  /// 행안부 안내의 표기 방법이다(예: "서울특별시 구로구 중앙로 5, 3층 (고척동)").
  String fullAddress(String? detail) {
    final buffer = StringBuffer(roadAddress);
    if (detail != null && detail.isNotEmpty) buffer.write(', $detail');
    if (roadAddressExtra case final extra?) buffer.write(' $extra');
    final text = buffer.toString();
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }
}

/// 서버 응답(AddressResponse) 하나. 테스트도 쓴다.
AddressCandidate addressCandidateFromJson(Object? json) {
  final map = _map(json);
  final ref = _map(map['ref']);
  return AddressCandidate(
    roadAddress: _text(map, 'roadAddress'),
    roadAddressExtra: _optionalText(map, 'roadAddressExtra'),
    jibunAddress: _text(map, 'jibunAddress'),
    buildingName: _optionalText(map, 'buildingName'),
    ref: AddressRef(Map.unmodifiable(ref)),
  );
}

AddressSearchResult _searchResultFromJson(Object? json) {
  final map = _map(json);
  return AddressSearchResult(
    detail: _optionalText(map, 'detail'),
    addresses: switch (map['addresses']) {
      final List<Object?> list => [
        for (final item in list) addressCandidateFromJson(item),
      ],
      _ => throw FormatException('addresses가 목록이 아닙니다', map),
    },
    totalCount: switch (map['totalCount']) {
      null => null,
      final int value => value,
      final value => throw FormatException(
        'totalCount: ${value.runtimeType}',
        map,
      ),
    },
  );
}

Map<String, Object?> _map(Object? json) => switch (json) {
  final Map<String, Object?> map => map,
  _ => throw FormatException('객체가 아닙니다', json),
};

String _text(Map<String, Object?> map, String key) => switch (map[key]) {
  final String value => value,
  final value => throw FormatException('$key: ${value.runtimeType}', map),
};

String? _optionalText(Map<String, Object?> map, String key) =>
    switch (map[key]) {
      null => null,
      final String value when value.trim().isEmpty => null,
      final String value => value,
      final value => throw FormatException('$key: ${value.runtimeType}', map),
    };

double _number(Map<String, Object?> map, String key) => switch (map[key]) {
  final num value => value.toDouble(),
  final value => throw FormatException('$key: ${value.runtimeType}', map),
};

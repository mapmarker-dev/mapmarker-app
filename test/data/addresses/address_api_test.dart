import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/data/addresses/address_api.dart';
import 'package:mapmarker_app/data/api/api_client.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_http.dart';

/// 서버 응답(AddressResponse)과 같은 모양.
Map<String, Object?> serverAddress({
  String road = '경기도 안양시 동안구 관악대로 472',
  String? extra = '(관양동)',
  String? building,
}) => {
  'roadAddress': road,
  'roadAddressExtra': extra,
  'jibunAddress': '경기도 안양시 동안구 관양동 1588',
  'buildingName': building,
  'zipCode': '14054',
  'ref': {
    'admCd': '4117310400',
    'rnMgtSn': '411734349005',
    'udrtYn': '0',
    'buldMnnm': 472,
    'buldSlno': 0,
  },
};

void main() {
  late FakeHttp http;
  late AddressApi api;

  setUp(() {
    http = FakeHttp(
      (_) => FakeReply.json(200, {
        'detail': '1,2층',
        'addresses': [
          serverAddress(),
          serverAddress(building: '롯데월드타워', extra: null),
        ],
      }),
    );
    final session = testSession();
    addTearDown(session.dispose);
    api = AddressApi(ApiClient(fakeDio(http), session));
  });

  group('search', () {
    test(
      'sends the text as the query and reads detail and addresses',
      () async {
        final result = await api.search('경기 안양시 동안구 관악대로 472 1,2층');

        final request = http.requests.single;
        expect(request.uri.path, '/v1/addresses');
        expect(
          request.uri.queryParameters['query'],
          '경기 안양시 동안구 관악대로 472 1,2층',
        );
        expect(result.detail, '1,2층');
        expect(result.addresses, hasLength(2));
        final first = result.addresses.first;
        expect(first.roadAddress, '경기도 안양시 동안구 관악대로 472');
        expect(first.roadAddressExtra, '(관양동)');
        expect(first.jibunAddress, '경기도 안양시 동안구 관양동 1588');
        expect(first.buildingName, isNull);
        expect(result.addresses.last.buildingName, '롯데월드타워');
      },
    );

    test(
      'reads the total count and has more when it exceeds the list',
      () async {
        http.handler = (_) => FakeReply.json(200, {
          'detail': null,
          'addresses': [for (var i = 0; i < 10; i++) serverAddress()],
          'totalCount': 1234,
        });

        final result = await api.search('강남역');

        expect(result.totalCount, 1234);
        expect(result.hasMore, isTrue);
      },
    );

    test('has no more when the total equals the list', () async {
      http.handler = (_) => FakeReply.json(200, {
        'detail': null,
        'addresses': [for (var i = 0; i < 10; i++) serverAddress()],
        'totalCount': 10,
      });

      expect((await api.search('관악대로 472')).hasMore, isFalse);
    });

    test('has no more when an older server sends no total count', () async {
      // setUp의 응답에는 totalCount가 없다.
      final result = await api.search('관악대로 472');

      expect(result.totalCount, 2);
      expect(result.hasMore, isFalse);
    });

    test(
      'throws a server failure for a total count that is not a number',
      () async {
        http.handler = (_) => FakeReply.json(200, {
          'detail': null,
          'addresses': [serverAddress()],
          'totalCount': '많음',
        });

        expect(
          () => api.search('관악대로 472'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure,
              'failure',
              ApiFailure.server,
            ),
          ),
        );
      },
    );

    test(
      'treats a query the server cannot search (400) as no result',
      () async {
        http.handler = (_) => FakeReply.json(400, {'message': '찾을 주소가 없습니다'});

        final result = await api.search('%');

        expect(result.addresses, isEmpty);
        expect(result.detail, isNull);
        expect(result.hasMore, isFalse);
      },
    );

    test('throws ApiException when the server is unavailable', () async {
      http.handler = (_) => FakeReply.json(503);

      expect(
        () => api.search('세종대로 110'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.unavailable,
          ),
        ),
      );
    });

    test('throws a server failure for a response it cannot read', () async {
      http.handler = (_) => FakeReply.json(200, {'addresses': 'nope'});

      expect(
        () => api.search('세종대로 110'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.server,
          ),
        ),
      );
    });
  });

  group('coordinates', () {
    test('sends the ref as the query and reads the position', () async {
      http.handler = (_) =>
          FakeReply.json(200, {'latitude': 37.4, 'longitude': 126.98});
      final address = addressCandidateFromJson(serverAddress());

      final position = await api.coordinates(address.ref);

      final request = http.requests.single;
      expect(request.uri.path, '/v1/addresses/coordinates');
      expect(request.uri.queryParameters, {
        'admCd': '4117310400',
        'rnMgtSn': '411734349005',
        'udrtYn': '0',
        'buldMnnm': '472',
        'buldSlno': '0',
      });
      expect(position, const LatLng(37.4, 126.98));
    });

    test('returns null when the building has no position (404)', () async {
      http.handler = (_) => FakeReply.json(404);
      final address = addressCandidateFromJson(serverAddress());

      expect(await api.coordinates(address.ref), isNull);
    });
  });

  group('fullAddress', () {
    final address = addressCandidateFromJson(serverAddress());

    test('puts the detail after a comma and the notes at the end', () {
      expect(address.fullAddress('1,2층'), '경기도 안양시 동안구 관악대로 472, 1,2층 (관양동)');
    });

    test('leaves out what is missing', () {
      expect(address.fullAddress(null), '경기도 안양시 동안구 관악대로 472 (관양동)');
      expect(
        addressCandidateFromJson(serverAddress(extra: null)).fullAddress(null),
        '경기도 안양시 동안구 관악대로 472',
      );
    });

    test('cuts it to the address length limit', () {
      expect(address.fullAddress('가' * 300).length, 200);
    });
  });
}

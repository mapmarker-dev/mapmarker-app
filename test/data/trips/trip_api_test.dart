import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/api/api_client.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/trip_api.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_http.dart';
import 'trip_json_test.dart' show serverSegment, serverStop, serverTrip;

Map<String, Object?> _detail() => {
  'trip': serverTrip(),
  'stops': [serverStop(), serverStop(id: 'stop-2', order: 1)],
  'segments': [serverSegment()],
};

void main() {
  late FakeHttp http;
  late TripApi api;

  setUp(() {
    http = FakeHttp((_) => FakeReply.json(200, _detail()));
    final session = testSession();
    addTearDown(session.dispose);
    api = TripApi(ApiClient(fakeDio(http), session));
  });

  String call() {
    final request = http.requests.single;
    return '${request.method} ${request.uri.path}';
  }

  final trip = Trip(
    id: 'trip-1',
    title: '부산 여행',
    region: '부산',
    nights: 2,
    season: Season.autumn,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  const stop = Stop(
    id: 'stop-1',
    tripId: 'trip-1',
    latitude: 35,
    longitude: 129,
    name: '해운대',
    day: 1,
    order: 0,
  );
  const segment = Segment(
    id: 'seg-1',
    tripId: 'trip-1',
    fromStopId: 'stop-1',
    toStopId: 'stop-2',
  );

  test('lists trips', () async {
    http.handler = (_) =>
        FakeReply.json(200, [serverTrip(id: 'a'), serverTrip(id: 'b')]);

    final trips = await api.listTrips();

    expect(call(), 'GET /v1/trips');
    expect([for (final trip in trips) trip.id], ['a', 'b']);
  });

  test('creates a trip', () async {
    http.handler = (_) => FakeReply.json(201, serverTrip());

    final saved = await api.createTrip(trip);

    expect(call(), 'POST /v1/trips');
    expect(http.requests.single.data, containsPair('id', 'trip-1'));
    expect(saved.updatedAt, DateTime.utc(2026, 10, 15, 3));
  });

  test('gets a trip with its route', () async {
    final detail = await api.getTrip('trip-1');

    expect(call(), 'GET /v1/trips/trip-1');
    expect(detail.route.stops, hasLength(2));
  });

  test('updates a trip', () async {
    http.handler = (_) => FakeReply.json(200, serverTrip());

    await api.updateTrip(trip);

    expect(call(), 'PATCH /v1/trips/trip-1');
    expect(http.requests.single.data, containsPair('dates', null));
  });

  test('deletes a trip', () async {
    http.handler = (_) => FakeReply.json(204);

    await api.deleteTrip('trip-1');

    expect(call(), 'DELETE /v1/trips/trip-1');
  });

  test('adds a stop under its trip and gets the new route', () async {
    final detail = await api.addStop(stop);

    expect(call(), 'POST /v1/trips/trip-1/stops');
    expect(http.requests.single.data, containsPair('order', 0));
    expect(detail.route.segments, hasLength(1));
  });

  test('updates a stop', () async {
    http.handler = (_) => FakeReply.json(200, serverStop());

    final saved = await api.updateStop(stop);

    expect(call(), 'PATCH /v1/stops/stop-1');
    expect(saved.name, '해운대');
  });

  test('moves a stop', () async {
    await api.moveStop('stop-1', day: 2, order: 3);

    expect(call(), 'PUT /v1/stops/stop-1/position');
    expect(http.requests.single.data, {'day': 2, 'order': 3});
  });

  test('deletes a stop and gets the new route', () async {
    final detail = await api.deleteStop('stop-1');

    expect(call(), 'DELETE /v1/stops/stop-1');
    expect(detail.trip.id, 'trip-1');
  });

  test('updates a segment', () async {
    http.handler = (_) => FakeReply.json(200, serverSegment());

    final saved = await api.updateSegment(segment);

    expect(call(), 'PATCH /v1/segments/seg-1');
    expect(http.requests.single.data, containsPair('legs', <Object?>[]));
    expect(saved.legs, hasLength(2));
  });

  test('passes server failures on as ApiException', () async {
    http.handler = (_) => FakeReply.json(409);

    await expectLater(
      api.addStop(stop),
      throwsA(
        isA<ApiException>().having(
          (e) => e.failure,
          'failure',
          ApiFailure.conflict,
        ),
      ),
    );
  });

  test('turns a response it cannot read into a server failure', () async {
    http.handler = (_) => const FakeReply.raw(200, '<html></html>');

    await expectLater(
      api.getTrip('trip-1'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.failure,
          'failure',
          ApiFailure.server,
        ),
      ),
    );
  });
}

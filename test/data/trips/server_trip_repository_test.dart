import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/api/api_client.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/server_trip_repository.dart';
import 'package:mapmarker_app/data/trips/trip_api.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_http.dart';
import 'trip_json_test.dart'
    show serverCandidate, serverSegment, serverStop, serverTrip;

/// 서버 대신 답한다. 경로마다 답을 바꿀 수 있다.
class _Server {
  _Server() {
    http = FakeHttp((request) {
      final key = '${request.method} ${request.uri.path.substring(3)}';
      final reply = replies[key];
      if (reply == null) throw StateError('답이 없는 요청: $key');
      return reply(request);
    });
  }

  late final FakeHttp http;
  final replies = <String, FutureOr<FakeReply> Function(RequestOptions)>{};

  List<String> get calls => [
    for (final request in http.requests)
      '${request.method} ${request.uri.path.substring(3)}',
  ];
}

Map<String, Object?> _detail({
  Map<String, Object?>? trip,
  List<Map<String, Object?>>? stops,
  List<Map<String, Object?>>? segments,
  List<Map<String, Object?>>? candidates,
}) => {
  'trip': trip ?? serverTrip(),
  'stops': stops ?? [serverStop(), serverStop(id: 'stop-2', order: 1)],
  'segments': segments ?? [serverSegment()],
  'candidates': candidates ?? [serverCandidate()],
};

/// [stream]의 값과 오류를 모은다.
List<Object?> _collect<T>(Stream<T> stream) {
  final events = <Object?>[];
  final subscription = stream.listen(events.add, onError: events.add);
  addTearDown(subscription.cancel);
  return events;
}

final _now = DateTime.utc(2026, 11, 1, 9);

void main() {
  late _Server server;
  late ServerTripRepository repository;

  setUp(() {
    server = _Server();
    final session = testSession();
    addTearDown(session.dispose);
    repository = ServerTripRepository(
      api: TripApi(ApiClient(fakeDio(server.http), session)),
      clock: () => _now,
    );
    addTearDown(repository.dispose);
    server.replies['GET /trips'] = (_) => FakeReply.json(200, [
      serverTrip(id: 'old', updatedAt: '2026-10-01T00:00:00.000Z'),
      serverTrip(id: 'trip-1'),
    ]);
    server.replies['GET /trips/trip-1'] = (_) => FakeReply.json(200, _detail());
  });

  List<String> ids(Object? trips) => [
    for (final trip in trips! as List<Trip>) trip.id,
  ];

  group('watchTrips', () {
    test('loads the list from the server, recently changed first', () async {
      final events = _collect(repository.watchTrips());
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(ids(events.single), ['trip-1', 'old']);
    });

    test('fails the first load with ApiException', () async {
      server.replies['GET /trips'] = (r) => throw connectionError(r);

      final events = _collect(repository.watchTrips());
      await pumpEventQueue();

      expect(
        events.single,
        isA<ApiException>().having(
          (e) => e.failure,
          'failure',
          ApiFailure.network,
        ),
      );
    });

    test('loads again when watched again after a failed first load', () async {
      server.replies['GET /trips'] = (r) => throw connectionError(r);
      final failed = repository.watchTrips().listen(null, onError: (_) {});
      await pumpEventQueue();
      await failed.cancel();
      server.replies['GET /trips'] = (_) => FakeReply.json(200, [serverTrip()]);

      final events = _collect(repository.watchTrips());
      await pumpEventQueue();

      expect(ids(events.last), ['trip-1']);
    });

    test(
      'shows what it remembers first, then refreshes in the background',
      () async {
        final first = repository.watchTrips().listen(null);
        await pumpEventQueue();
        await first.cancel();
        server.replies['GET /trips'] = (_) => FakeReply.json(200, [
          serverTrip(id: 'new', updatedAt: '2026-10-20T00:00:00.000Z'),
        ]);

        final events = _collect(repository.watchTrips());
        await pumpEventQueue();

        expect(ids(events.first), ['trip-1', 'old']);
        expect(ids(events.last), ['new']);
      },
    );

    test(
      'keeps the list when a refresh fails, and reports it to the caller',
      () async {
        final events = _collect(repository.watchTrips());
        await pumpEventQueue();
        server.replies['GET /trips'] = (r) => throw connectionError(r);

        await expectLater(
          repository.refreshTrips(),
          throwsA(isA<ApiException>()),
        );
        await pumpEventQueue();

        expect(events.whereType<ApiException>(), isEmpty);
        expect(ids(events.last), ['trip-1', 'old']);
      },
    );
  });

  group('watchTrip and watchRoute', () {
    test('load the trip and its route', () async {
      final trips = _collect(repository.watchTrip('trip-1'));
      final routes = _collect(repository.watchRoute('trip-1'));
      await pumpEventQueue();

      expect((trips.last! as Trip).id, 'trip-1');
      expect((routes.last! as TripRoute).stops, hasLength(2));
      // 두 스트림이 함께 열려도 한 번만 받는다.
      expect(server.calls.where((c) => c == 'GET /trips/trip-1'), hasLength(1));
    });

    test('show the trip from the list before its route arrives', () async {
      final list = repository.watchTrips().listen(null);
      await pumpEventQueue();
      final detail = Completer<FakeReply>();
      server.replies['GET /trips/trip-1'] = (_) => detail.future;

      final trips = _collect(repository.watchTrip('trip-1'));
      final routes = _collect(repository.watchRoute('trip-1'));
      await pumpEventQueue();

      expect((trips.single! as Trip).id, 'trip-1');
      expect(routes, isEmpty);
      detail.complete(FakeReply.json(200, _detail()));
      await pumpEventQueue();
      expect(routes, hasLength(1));
      await list.cancel();
    });

    test('treat a trip the server does not have as gone', () async {
      final list = _collect(repository.watchTrips());
      await pumpEventQueue();
      server.replies['GET /trips/trip-1'] = (_) => FakeReply.json(404);

      final trips = _collect(repository.watchTrip('trip-1'));
      final routes = _collect(repository.watchRoute('trip-1'));
      await pumpEventQueue();

      expect(trips.last, isNull);
      expect((routes.last! as TripRoute).stops, isEmpty);
      expect(ids(list.last), ['old']);
    });

    test('fail when the first load fails', () async {
      server.replies['GET /trips/trip-1'] = (r) => throw connectionError(r);

      final routes = _collect(repository.watchRoute('trip-1'));
      await pumpEventQueue();

      expect(routes.single, isA<ApiException>());
    });
  });

  group('writes', () {
    final trip = Trip(
      id: 'trip-1',
      title: '부산 여행',
      region: '부산',
      nights: 2,
      season: Season.autumn,
      createdAt: _now,
      updatedAt: _now,
    );
    const stop = Stop(
      id: 'stop-3',
      tripId: 'trip-1',
      latitude: 35,
      longitude: 129,
      name: '광안리',
      day: 1,
      order: 2,
    );

    Future<void> loadTrip() async {
      final route = repository.watchRoute('trip-1').listen(null);
      addTearDown(route.cancel);
      await pumpEventQueue();
    }

    test('createTrip adds the saved trip with an empty route', () async {
      final list = _collect(repository.watchTrips());
      await pumpEventQueue();
      server.replies['POST /trips'] = (_) => FakeReply.json(
        201,
        serverTrip(id: 'made', updatedAt: '2026-11-01T00:00:00.000Z'),
      );

      final saved = await repository.createTrip(
        Trip(
          id: 'made',
          title: '새 여행',
          region: '부산',
          nights: 0,
          season: Season.autumn,
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      // 들어가면 뒤에서 다시 받지만, 그 답을 기다리지 않고 빈 동선을 바로 보여 준다.
      server.replies['GET /trips/made'] = (_) => Completer<FakeReply>().future;
      final routes = _collect(repository.watchRoute('made'));
      await pumpEventQueue();

      expect(saved.id, 'made');
      expect(ids(list.last).first, 'made');
      expect((routes.single! as TripRoute).stops, isEmpty);
    });

    test('updateTrip keeps what the server returns', () async {
      final trips = _collect(repository.watchTrip('trip-1'));
      await pumpEventQueue();
      server.replies['PATCH /trips/trip-1'] = (_) =>
          FakeReply.json(200, {...serverTrip(), 'title': '서버 제목'});

      await repository.updateTrip(trip);
      await pumpEventQueue();

      expect((trips.last! as Trip).title, '서버 제목');
    });

    test(
      'addStop, moveStop and deleteStop take the route the server returns',
      () async {
        await loadTrip();
        final routes = _collect(repository.watchRoute('trip-1'));
        final three = [
          serverStop(),
          serverStop(id: 'stop-2', order: 1),
          serverStop(id: 'stop-3', order: 2),
        ];
        server.replies['POST /trips/trip-1/stops'] = (_) =>
            FakeReply.json(201, _detail(stops: three));
        server.replies['PUT /stops/stop-3/position'] = (_) =>
            FakeReply.json(200, _detail(stops: three.reversed.toList()));
        server.replies['DELETE /stops/stop-3'] = (_) =>
            FakeReply.json(200, _detail(stops: [serverStop()], segments: []));

        final added = await repository.addStop(stop);
        await pumpEventQueue();
        expect(added.id, 'stop-3');
        expect((routes.last! as TripRoute).stops, hasLength(3));

        final moved = await repository.moveStop('stop-3', day: 1, order: 0);
        expect(moved.id, 'stop-3');

        await repository.deleteStop('stop-3');
        await pumpEventQueue();
        expect((routes.last! as TripRoute).stops.single.id, 'stop-1');
        expect((routes.last! as TripRoute).segments, isEmpty);
      },
    );

    test(
      'updateStop replaces the stop and marks the trip changed now',
      () async {
        await loadTrip();
        final trips = _collect(repository.watchTrip('trip-1'));
        final routes = _collect(repository.watchRoute('trip-1'));
        await pumpEventQueue();
        server.replies['PATCH /stops/stop-1'] = (_) =>
            FakeReply.json(200, {...serverStop(), 'name': '서버 이름'});

        await repository.updateStop(
          stopFromRoute(routes.last! as TripRoute, 'stop-1'),
        );
        await pumpEventQueue();

        expect((routes.last! as TripRoute).stopById('stop-1')?.name, '서버 이름');
        // 응답에 여행이 없어서 앱 시각으로 맞춘다. 다음에 받을 때 서버 값으로 바뀐다.
        expect((trips.last! as Trip).updatedAt, _now);
        // 장소 하나를 바꿔도 후보는 그대로다.
        expect((routes.last! as TripRoute).candidates.single.id, 'cand-1');
      },
    );

    test(
      'addCandidate, updateCandidate and deleteCandidate change only the candidates',
      () async {
        await loadTrip();
        final trips = _collect(repository.watchTrip('trip-1'));
        final routes = _collect(repository.watchRoute('trip-1'));
        await pumpEventQueue();
        TripRoute last() => routes.last! as TripRoute;
        server.replies['POST /trips/trip-1/candidates'] = (_) =>
            FakeReply.json(201, serverCandidate(id: 'cand-2', name: '비자림'));
        server.replies['PATCH /candidates/cand-1'] = (_) =>
            FakeReply.json(200, serverCandidate(name: '서버 이름'));
        server.replies['DELETE /candidates/cand-1'] = (_) =>
            FakeReply.json(204);

        final added = await repository.addCandidate(
          const Candidate(
            id: 'cand-2',
            tripId: 'trip-1',
            latitude: 33.4,
            longitude: 126.8,
            name: '비자림',
          ),
        );
        await pumpEventQueue();
        expect(added.id, 'cand-2');
        expect([for (final c in last().candidates) c.id], ['cand-1', 'cand-2']);

        await repository.updateCandidate(last().candidateById('cand-1')!);
        await pumpEventQueue();
        expect([for (final c in last().candidates) c.name], ['서버 이름', '비자림']);

        await repository.deleteCandidate('cand-1');
        await pumpEventQueue();
        expect([for (final c in last().candidates) c.id], ['cand-2']);
        expect(last().stops, hasLength(2));
        expect((trips.last! as Trip).updatedAt, _now);
      },
    );

    test(
      'promoteCandidate and demoteStop take the route the server returns',
      () async {
        await loadTrip();
        final routes = _collect(repository.watchRoute('trip-1'));
        TripRoute last() => routes.last! as TripRoute;
        server.replies['POST /candidates/cand-1/stop'] = (_) => FakeReply.json(
          200,
          _detail(
            stops: [
              serverStop(),
              serverStop(id: 'cand-1', order: 1),
              serverStop(id: 'stop-2', order: 2),
            ],
            candidates: [],
          ),
        );
        server.replies['POST /stops/cand-1/candidate'] = (_) =>
            FakeReply.json(200, _detail());

        final placed = await repository.promoteCandidate(
          const Stop(
            id: 'cand-1',
            tripId: 'trip-1',
            latitude: 33.5,
            longitude: 127,
            name: '우도',
            day: 1,
            order: 1,
          ),
        );
        await pumpEventQueue();
        expect(placed.id, 'cand-1');
        expect(last().stops, hasLength(3));
        expect(last().candidates, isEmpty);

        final candidate = await repository.demoteStop('cand-1');
        await pumpEventQueue();
        expect(candidate.id, 'cand-1');
        expect(last().stops, hasLength(2));
        expect(last().candidateById('cand-1'), isNotNull);
      },
    );

    test('a failed demoteStop reloads the trip and throws', () async {
      await loadTrip();
      server.replies['POST /stops/stop-1/candidate'] = (_) =>
          FakeReply.json(409);

      await expectLater(
        repository.demoteStop('stop-1'),
        throwsA(isA<ApiException>()),
      );
      await pumpEventQueue();

      // 응답만 잃었을 수 있어서 다시 받는다.
      expect(server.calls.where((c) => c == 'GET /trips/trip-1'), hasLength(2));
    });

    test(
      'updateSegment replaces the segment and marks the trip changed now',
      () async {
        await loadTrip();
        final trips = _collect(repository.watchTrip('trip-1'));
        final routes = _collect(repository.watchRoute('trip-1'));
        await pumpEventQueue();
        server.replies['PATCH /segments/seg-1'] = (_) =>
            FakeReply.json(200, {...serverSegment(), 'curvature': 0.5});

        final saved = await repository.updateSegment(
          (routes.last! as TripRoute).segments.single,
        );
        await pumpEventQueue();

        expect(saved.curvature, 0.5);
        expect((routes.last! as TripRoute).segments.single.curvature, 0.5);
        expect((trips.last! as Trip).updatedAt, _now);
      },
    );

    test('sends writes to one trip one at a time', () async {
      await loadTrip();
      final first = Completer<FakeReply>();
      server.replies['PATCH /trips/trip-1'] = (_) => first.future;
      server.replies['PATCH /stops/stop-1'] = (_) =>
          FakeReply.json(200, serverStop());

      final stop1 = stopFromRoute(
        await repository.watchRoute('trip-1').first,
        'stop-1',
      );
      await pumpEventQueue();
      final rename = repository.updateTrip(trip);
      final edit = repository.updateStop(stop1);
      await pumpEventQueue();
      expect(server.calls.last, 'PATCH /trips/trip-1');

      first.complete(FakeReply.json(200, serverTrip()));
      await rename;
      await edit;
      expect(server.calls.last, 'PATCH /stops/stop-1');
    });

    test('drops a load that overlapped a write', () async {
      await loadTrip();
      final routes = _collect(repository.watchRoute('trip-1'));
      final stale = Completer<FakeReply>();
      server.replies['GET /trips/trip-1'] = (_) => stale.future;
      server.replies['DELETE /stops/stop-2'] = (_) =>
          FakeReply.json(200, _detail(stops: [serverStop()], segments: []));

      final refresh = repository.refreshTrip('trip-1');
      await pumpEventQueue();
      await repository.deleteStop('stop-2');
      // 지우기 전에 읽은 동선이 뒤늦게 온다.
      stale.complete(FakeReply.json(200, _detail()));
      await refresh;
      await pumpEventQueue();

      expect((routes.last! as TripRoute).stops, hasLength(1));
    });

    test(
      'a failed write throws and reloads the trip, since only the response may be lost',
      () async {
        await loadTrip();
        server.replies['POST /trips/trip-1/stops'] = (r) =>
            throw connectionError(r);
        final before = server.calls.length;

        await expectLater(
          repository.addStop(stop),
          throwsA(isA<ApiException>()),
        );
        await pumpEventQueue();

        expect(server.calls.skip(before), [
          'POST /trips/trip-1/stops',
          'GET /trips/trip-1',
        ]);
      },
    );

    test('a write the server rejects as stale also reloads the trip', () async {
      await loadTrip();
      server.replies['POST /trips/trip-1/stops'] = (_) => FakeReply.json(409);
      final before = server.calls.length;

      await expectLater(
        repository.addStop(stop),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.conflict,
          ),
        ),
      );
      await pumpEventQueue();

      expect(server.calls.skip(before), contains('GET /trips/trip-1'));
    });

    test('trashTrip drops the trip from the list and its detail', () async {
      await loadTrip();
      final list = _collect(repository.watchTrips());
      final trips = _collect(repository.watchTrip('trip-1'));
      await pumpEventQueue();
      server.replies['DELETE /trips/trip-1'] = (_) => FakeReply.json(204);

      await repository.trashTrip('trip-1');
      await pumpEventQueue();

      expect(ids(list.last), ['old']);
      expect(trips.last, isNull);
    });

    test(
      'trashTrip treats a trip the server no longer has as trashed',
      () async {
        await loadTrip();
        final list = _collect(repository.watchTrips());
        await pumpEventQueue();
        server.replies['DELETE /trips/trip-1'] = (_) =>
            FakeReply.json(404, {'message': 'not found'});

        await repository.trashTrip('trip-1');
        await pumpEventQueue();

        expect(ids(list.last), ['old']);
      },
    );

    test('a failed trashTrip keeps the trip and throws', () async {
      await loadTrip();
      final list = _collect(repository.watchTrips());
      await pumpEventQueue();
      server.replies['DELETE /trips/trip-1'] = (r) => throw connectionError(r);

      await expectLater(
        repository.trashTrip('trip-1'),
        throwsA(isA<ApiException>()),
      );
      await pumpEventQueue();

      expect(ids(list.last), ['trip-1', 'old']);
    });

    test('fetchTrash asks the server every time', () async {
      server.replies['GET /trash'] = (_) => FakeReply.json(200, [
        {
          ...serverTrip(id: 'gone'),
          'deletedAt': '2026-11-10T08:30:00.000Z',
          'purgeAt': '2026-12-10T08:30:00.000Z',
        },
      ]);

      final first = await repository.fetchTrash();
      await repository.fetchTrash();

      expect(first.single.trip.id, 'gone');
      expect(server.calls, ['GET /trash', 'GET /trash']);
    });

    test(
      'restoreTrip puts the trip back in the list at its old place',
      () async {
        final list = _collect(repository.watchTrips());
        await pumpEventQueue();
        server.replies['POST /trash/gone/restore'] = (_) => FakeReply.json(
          200,
          serverTrip(id: 'gone', updatedAt: '2026-09-01T00:00:00.000Z'),
        );

        final restored = await repository.restoreTrip('gone');
        await pumpEventQueue();

        expect(restored.id, 'gone');
        expect(ids(list.last), ['trip-1', 'old', 'gone']);
        // 동선은 아직 받지 않았다. 여행을 열면 받는다.
        server.replies['GET /trips/gone'] = (_) =>
            FakeReply.json(200, _detail(trip: serverTrip(id: 'gone')));
        final route = _collect(repository.watchRoute('gone'));
        await pumpEventQueue();
        expect(server.calls, contains('GET /trips/gone'));
        expect((route.last! as TripRoute).stops, hasLength(2));
      },
    );

    test(
      'restoreTrip throws when the trip is no longer in the trash',
      () async {
        final list = _collect(repository.watchTrips());
        await pumpEventQueue();
        server.replies['POST /trash/gone/restore'] = (_) =>
            FakeReply.json(404, {'message': 'not found'});

        await expectLater(
          repository.restoreTrip('gone'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure,
              'failure',
              ApiFailure.notFound,
            ),
          ),
        );
        await pumpEventQueue();

        expect(ids(list.last), ['trip-1', 'old']);
      },
    );

    test(
      'deleteTripForever treats a trip the server no longer has as deleted',
      () async {
        server.replies['DELETE /trash/gone'] = (_) => FakeReply.json(204);
        await repository.deleteTripForever('gone');

        server.replies['DELETE /trash/gone'] = (_) =>
            FakeReply.json(404, {'message': 'not found'});
        await repository.deleteTripForever('gone');

        server.replies['DELETE /trash/gone'] = (r) => throw connectionError(r);
        await expectLater(
          repository.deleteTripForever('gone'),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test('a failed createTrip reloads the list', () async {
      final list = repository.watchTrips().listen(null);
      addTearDown(list.cancel);
      await pumpEventQueue();
      server.replies['POST /trips'] = (r) => throw connectionError(r);
      final before = server.calls.length;

      await expectLater(
        repository.createTrip(
          Trip(
            id: 'unsaved',
            title: '새 여행',
            region: '부산',
            nights: 0,
            season: Season.autumn,
            createdAt: _now,
            updatedAt: _now,
          ),
        ),
        throwsA(isA<ApiException>()),
      );
      await pumpEventQueue();

      expect(server.calls.skip(before), ['POST /trips', 'GET /trips']);
    });
  });

  group('refreshWatched', () {
    test('reloads what is being watched and ignores failures', () async {
      final list = repository.watchTrips().listen(null);
      final route = repository.watchRoute('trip-1').listen(null);
      addTearDown(list.cancel);
      addTearDown(route.cancel);
      await pumpEventQueue();
      final before = server.calls.length;
      server.replies['GET /trips'] = (r) => throw connectionError(r);

      repository.refreshWatched();
      await pumpEventQueue();

      expect(
        server.calls.skip(before),
        unorderedEquals(['GET /trips', 'GET /trips/trip-1']),
      );
    });

    test('does not reload what is no longer watched', () async {
      final route = repository.watchRoute('trip-1').listen(null);
      await pumpEventQueue();
      await route.cancel();
      final before = server.calls.length;

      repository.refreshWatched();
      await pumpEventQueue();

      expect(server.calls.skip(before), isEmpty);
    });
  });
}

Stop stopFromRoute(TripRoute route, String id) => route.stopById(id)!;

import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/sample/jeju_sample.dart';
import 'package:mapmarker_app/data/sample/sample_trip_repository.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';

import '../../helpers/memory_sample_store.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

void main() {
  final sample = jejuSample(testL10n);

  group('jejuSample', () {
    test('is an undated 3-night autumn trip in Jeju', () {
      expect(sample.trip.id, sampleTripId);
      expect(sample.trip.title, '제주 3박 4일 가을 여행');
      expect(sample.trip.dates, isNull);
      expect(sample.trip.nights, 3);
    });

    test('links every stop and fills in transport and curves', () {
      final route = sample.route;
      expect(route.stops, hasLength(13));
      // 이웃한 장소마다 구간이 하나다(같은 숙소를 다시 넣은 곳도 잇는다).
      expect(route.segments, hasLength(12));
      final written = route.segments.where((s) => s.legs.isNotEmpty);
      expect(written, hasLength(10));
      expect(route.segments.where((s) => s.curvature != 0), hasLength(3));
      // 동선에 없는 후보도 있다.
      expect(route.candidates.map((c) => c.name), [
        '비자림',
        '애월 카페거리',
        '한라산 영실 탐방로',
      ]);
      expect(route.candidates.every((c) => c.tripId == sampleTripId), isTrue);
      final stopNames = {for (final s in route.stops) s.name};
      expect(route.candidates.any((c) => stopNames.contains(c.name)), isFalse);
      // 선 모양 3갈래가 다 있다: 자동차(실선), 도보(점선), 배(파선).
      final modes = {for (final s in written) ...s.legs.map((l) => l.mode)};
      expect(
        modes,
        containsAll([
          TransportMode.car,
          TransportMode.walk,
          TransportMode.ferry,
        ]),
      );
    });
  });

  group('SampleTripRepository', () {
    late MemoryTripRepository inner;
    late MemorySampleStore store;
    late SampleTripRepository repository;

    SampleTripRepository open() {
      final opened = SampleTripRepository(
        inner: inner,
        store: store,
        sample: sample,
      );
      addTearDown(opened.dispose);
      return opened;
    }

    setUp(() async {
      inner = testRepository([testTrip(id: 'busan')]);
      store = MemorySampleStore();
      repository = open();
      await pumpEventQueue();
    });

    List<String> ids(List<Trip> trips) => [for (final t in trips) t.id];

    test('puts the sample after the user trips', () async {
      expect(ids(await repository.watchTrips().first), ['busan', sampleTripId]);
      expect(await repository.watchTrip(sampleTripId).first, sample.trip);
      expect(await repository.watchRoute(sampleTripId).first, sample.route);
    });

    test('hides the sample when trashed and remembers it', () async {
      final lists = <List<String>>[];
      final subscription = repository.watchTrips().listen(
        (trips) => lists.add(ids(trips)),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repository.trashTrip(sampleTripId);
      await pumpEventQueue();

      expect(lists.last, ['busan']);
      expect(await repository.watchTrip(sampleTripId).first, isNull);
      expect(store.hides, 1);
      // 다시 로그인해도(저장소를 새로 만들어도) 보이지 않는다.
      final again = open();
      await pumpEventQueue();
      expect(ids(await again.watchTrips().first), ['busan']);
    });

    test(
      'does not show the sample until it knows whether it was hidden',
      () async {
        store.hidden = true;
        final fresh = open();

        expect(ids(await fresh.watchTrips().first), ['busan']);
      },
    );

    test('passes other trips through to the user repository', () async {
      await repository.createTrip(testTrip(id: 'jeju', region: '제주'));
      await repository.addStop(testStop('a', tripId: 'jeju'));
      await repository.trashTrip('busan');

      expect(ids(await repository.watchTrips().first), ['jeju', sampleTripId]);
      expect(ids(await inner.watchTrips().first), ['jeju']);
      expect((await repository.watchRoute('jeju').first).stops, hasLength(1));
      // 휴지통도 사용자 저장소의 것이다. 샘플은 휴지통에 들어가지 않는다.
      await repository.trashTrip(sampleTripId);
      expect(
        [for (final t in await repository.fetchTrash()) t.trip.id],
        ['busan'],
      );
      expect((await repository.restoreTrip('busan')).id, 'busan');
      await repository.trashTrip('busan');
      await repository.deleteTripForever('busan');
      expect(await inner.fetchTrash(), isEmpty);
    });

    test('refuses to change the sample', () async {
      final stop = sample.route.stops.first;
      final segment = sample.route.segments.first;

      expect(repository.updateTrip(sample.trip), throwsStateError);
      expect(
        repository.addStop(testStop('new', tripId: sampleTripId)),
        throwsStateError,
      );
      expect(repository.updateStop(stop), throwsStateError);
      expect(repository.moveStop(stop.id, day: 2, order: 0), throwsStateError);
      expect(repository.deleteStop(stop.id), throwsStateError);
      expect(repository.updateSegment(segment), throwsStateError);
      expect(
        repository.addCandidate(
          const Candidate(
            id: 'new',
            tripId: sampleTripId,
            latitude: 33.5,
            longitude: 126.9,
            name: '우도',
          ),
        ),
        throwsStateError,
      );
      expect(repository.demoteStop(stop.id), throwsStateError);
      expect(
        repository.promoteCandidate(testStop('new', tripId: sampleTripId)),
        throwsStateError,
      );
    });
  });
}

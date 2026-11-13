import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/api/api_exception.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/sample/copy_trip.dart';
import 'package:mapmarker_app/data/sample/jeju_sample.dart';

import '../../helpers/flaky_trip_repository.dart';
import '../../helpers/test_app.dart';

/// 장소를 [okStops]개 넣은 뒤로는 넣기에 실패한다.
class _FailingStops extends FlakyTripRepository {
  _FailingStops(super.inner, {required this.okStops});

  int okStops;

  @override
  Future<Stop> addStop(Stop stop) async {
    if (okStops-- <= 0) throw const ApiException(ApiFailure.network);
    return super.addStop(stop);
  }
}

/// 후보 넣기에 실패한다(장소는 모두 들어간 뒤).
class _FailingCandidates extends FlakyTripRepository {
  _FailingCandidates(super.inner);

  @override
  Future<Candidate> addCandidate(Candidate candidate) async =>
      throw const ApiException(ApiFailure.network);
}

void main() {
  final sample = jejuSample(testL10n);

  test('copies the sample into a new trip of the user', () async {
    final repository = testRepository();
    var count = 0;

    final trip = await copySample(
      repository,
      sample,
      createId: () => 'new-${++count}',
    );

    expect(trip.id, 'new-1');
    expect(trip.title, sample.trip.title);
    expect(trip.dates, isNull);
    final route = await repository.watchRoute(trip.id).first;
    expect(
      route.stops.map((s) => (s.name, s.day, s.order, s.kind)),
      sample.route.stops.map((s) => (s.name, s.day, s.order, s.kind)),
    );
    expect(route.stops.every((s) => !isSampleTrip(s.tripId)), isTrue);
    expect(
      route.stops.map((s) => s.plannedTime),
      sample.route.stops.map((s) => s.plannedTime),
    );
    String pair(TripRoute r, String from, String to) =>
        '${r.stopById(from)!.name}>${r.stopById(to)!.name}';
    // 목록은 같은 값이어도 다른 객체라서 글자로 견준다.
    String look(Segment s) =>
        '${[for (final l in s.legs) '${l.mode.name}/${l.stopCount}/${l.duration}']} ${s.curvature}';
    final copied = {
      for (final s in route.segments)
        pair(route, s.fromStopId, s.toStopId): look(s),
    };
    final original = {
      for (final s in sample.route.segments)
        pair(sample.route, s.fromStopId, s.toStopId): look(s),
    };
    expect(copied, original);
    // 후보도 같은 순서로 새 ID로 들어간다.
    expect(
      route.candidates.map((c) => (c.name, c.kind, c.description, c.memo)),
      sample.route.candidates.map(
        (c) => (c.name, c.kind, c.description, c.memo),
      ),
    );
    expect(
      route.candidates.map((c) => c.position),
      sample.route.candidates.map((c) => c.position),
    );
    expect(route.candidates.every((c) => c.tripId == trip.id), isTrue);
    expect(route.candidates.every((c) => !c.id.startsWith('sample')), isTrue);
  });

  test('deletes the half-made trip when copying a candidate fails', () async {
    final repository = _FailingCandidates(testRepository());

    await expectLater(
      copySample(repository, sample),
      throwsA(isA<ApiException>()),
    );

    expect(await repository.watchTrips().first, isEmpty);
    expect(await repository.fetchTrash(), isEmpty);
  });

  test('deletes the half-made trip and throws when copying fails', () async {
    final repository = _FailingStops(testRepository(), okStops: 3);

    await expectLater(
      copySample(repository, sample),
      throwsA(isA<ApiException>()),
    );

    expect(await repository.watchTrips().first, isEmpty);
    // 휴지통을 거치지 않고 영구 삭제한다.
    expect(await repository.fetchTrash(), isEmpty);
  });
}

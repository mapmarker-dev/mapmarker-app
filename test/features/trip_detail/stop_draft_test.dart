import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/geo.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/features/trip_detail/stop_draft.dart';

import '../../helpers/test_stops.dart';

void main() {
  group('isValid', () {
    test('needs a name', () {
      expect(const StopDraft(day: 1).isValid, isFalse);
      expect(const StopDraft(name: '   ', day: 1).isValid, isFalse);
      expect(const StopDraft(name: '용두암', day: 1).isValid, isTrue);
    });

    test('limits the name to 50 letters, not counting spaces around it', () {
      expect(StopDraft(name: '가' * 50, day: 1).isValid, isTrue);
      expect(StopDraft(name: ' ${'가' * 50} ', day: 1).isValid, isTrue);
      expect(StopDraft(name: '가' * 51, day: 1).isValid, isFalse);
    });

    test('limits the description and memo to 1000 letters', () {
      const ok = StopDraft(name: '용두암', day: 1);

      expect(ok.copyWith(description: 'a' * 1000).isValid, isTrue);
      expect(ok.copyWith(description: 'a' * 1001).isValid, isFalse);
      expect(ok.copyWith(memo: 'a' * 1001).isValid, isFalse);
    });
  });

  test('makes a new stop with trimmed text', () {
    const draft = StopDraft(
      name: ' 용두암 ',
      kind: StopKind.tour,
      day: 2,
      plannedTime: LocalTime(9, 30),
      description: ' 바위 ',
      memo: '\n주차\n',
    );

    final stop = draft.toNewStop(
      id: 'new',
      tripId: 'jeju',
      position: const LatLng(33.51, 126.51),
      order: 1,
    );

    expect(stop.id, 'new');
    expect(stop.tripId, 'jeju');
    expect(stop.position, const LatLng(33.51, 126.51));
    expect((stop.day, stop.order), (2, 1));
    expect(stop.name, '용두암');
    expect(stop.kind, StopKind.tour);
    expect(stop.plannedTime, const LocalTime(9, 30));
    expect(stop.description, '바위');
    expect(stop.memo, '주차');
  });

  test('edits a stop but leaves its day and place to the repository', () {
    final stop = testStop(
      'c',
      day: 2,
      order: 1,
    ).copyWith(plannedTime: () => const LocalTime(14, 0));
    final draft = StopDraft.of(stop).copyWith(
      name: '카페',
      kind: StopKind.food,
      day: 3,
      plannedTime: () => null,
    );

    final edited = draft.applyTo(stop);

    expect(edited.name, '카페');
    expect(edited.kind, StopKind.food);
    expect(edited.plannedTime, isNull);
    expect((edited.day, edited.order), (2, 1));
    expect(edited.position, stop.position);
  });

  test('knows when nothing changed', () {
    final stop = testStop('c');

    expect(StopDraft.of(stop), StopDraft.of(stop));
    expect(StopDraft.of(stop).copyWith(memo: '메모'), isNot(StopDraft.of(stop)));
  });
}

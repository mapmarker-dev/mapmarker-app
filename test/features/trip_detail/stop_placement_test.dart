import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/features/trip_detail/stop_draft.dart';
import 'package:mapmarker_app/features/trip_detail/stop_placement.dart';

import '../../helpers/test_stops.dart';

const _subway = [TransportLeg(TransportMode.subway, stopCount: 2)];
const _walk = [TransportLeg(TransportMode.walk)];

Segment _segment(
  String from,
  String to, {
  List<TransportLeg> legs = const [],
}) => Segment(
  id: '$from>$to',
  tripId: 'trip',
  fromStopId: from,
  toStopId: to,
  legs: legs,
);

List<String> _ids(List<Segment> segments) => [for (final s in segments) s.id];

void main() {
  group('insertionOrder', () {
    test('puts a stop at the end of the day', () {
      expect(insertionOrder([], StopKind.other), 0);
      expect(insertionOrder([testStop('a'), testStop('b')], StopKind.food), 2);
    });

    test('keeps the lodging of the night last', () {
      final day = [testStop('a'), testLodging('hotel', order: 1)];

      expect(insertionOrder(day, StopKind.tour), 1);
      expect(insertionOrder([testLodging('hotel')], StopKind.other), 0);
    });

    test('puts new lodging at the very end', () {
      final day = [testStop('a'), testLodging('hotel', order: 1)];

      expect(insertionOrder(day, StopKind.lodging), 2);
    });
  });

  group('insertionSlots', () {
    test('are the gaps around every stop of the day', () {
      final slots = insertionSlots([
        testStop('a'),
        testStop('b', order: 1),
      ], StopKind.other);

      expect([for (final s in slots) s.order], [0, 1, 2]);
      expect(
        [for (final s in slots) (s.before?.id, s.after?.id)],
        [(null, 'a'), ('a', 'b'), ('b', null)],
      );
    });

    test('keep the lodging of the night last', () {
      final day = [testStop('a'), testLodging('hotel', order: 1)];

      final slots = insertionSlots(day, StopKind.food);

      expect(
        [for (final s in slots) (s.before?.id, s.after?.id)],
        [(null, 'a'), ('a', 'hotel')],
      );
    });

    test('let new lodging go after the lodging of the night', () {
      // 숙소를 옮기는 날: 숙소A > 장소 > 숙소B.
      final day = [testStop('a'), testLodging('hotel', order: 1)];

      final slots = insertionSlots(day, StopKind.lodging);

      expect([for (final s in slots) s.order], [0, 1, 2]);
    });

    test('keep the gap after a lodging visited during the day', () {
      // 장소 > 숙소 > 장소: 마지막이 숙소가 아니라 숙소 뒤도 고를 수 있다.
      final day = [
        testStop('a'),
        testLodging('hotel', order: 1),
        testStop('b', order: 2),
      ];

      expect(insertionSlots(day, StopKind.food).length, 4);
    });

    test('are a single gap on an empty day', () {
      final slots = insertionSlots(const [], StopKind.other);

      expect(slots.single.order, 0);
      expect((slots.single.before, slots.single.after), (null, null));
    });
  });

  group('placing a draft', () {
    // 1일차: a > b(지하철) > 숙소(도보), 2일차: c.
    final route = TripRoute(
      stops: [
        testStop('a'),
        testStop('b', order: 1),
        testLodging('hotel', order: 2),
        testStop('c', day: 2),
      ],
      segments: [
        _segment('a', 'b', legs: _subway),
        _segment('b', 'hotel', legs: _walk),
        _segment('hotel', 'c'),
      ],
    );
    final b = route.stopById('b')!;

    test('goes to the default slot unless one is chosen', () {
      const draft = StopDraft(name: '새 장소', day: 1);

      expect(placedOrder(route, draft), 2);
      expect(placedOrder(route, draft.copyWith(kind: StopKind.lodging)), 3);
      expect(placedOrder(route, draft.copyWith(slotOrder: () => 0)), 0);
    });

    test(
      'falls back to the default slot when the chosen one is not offered',
      () {
        // 숙소로 그날 밤 숙소 뒤를 골랐다가 종류를 바꿨다.
        final draft = const StopDraft(
          name: '새 장소',
          day: 1,
          kind: StopKind.lodging,
        ).copyWith(slotOrder: () => 3);

        expect(placedOrder(route, draft), 3);
        expect(placedOrder(route, draft.copyWith(kind: StopKind.food)), 2);
      },
    );

    test('leaves the moved stop out of its new day', () {
      final draft = StopDraft.of(b).copyWith(day: 1, slotOrder: () => null);

      expect(placedOrder(route, draft, stopId: 'b'), 1);
    });

    test('drops the written transport across the chosen gap', () {
      const draft = StopDraft(name: '새 장소', day: 1);

      expect(_ids(transportsDroppedByDraft(route, draft)), ['b>hotel']);
      expect(
        _ids(
          transportsDroppedByDraft(route, draft.copyWith(slotOrder: () => 1)),
        ),
        ['a>b'],
      );
      // 숙소 뒤의 구간(숙소 → c)은 이동 수단이 미정이라 알릴 것이 없다.
      expect(
        transportsDroppedByDraft(
          route,
          draft.copyWith(kind: StopKind.lodging, slotOrder: () => 3),
        ),
        isEmpty,
      );
    });

    test('drops the transport into and out of a stop moved to another day', () {
      final draft = StopDraft.of(b).copyWith(day: 2);

      expect(_ids(transportsDroppedByDraft(route, draft, stop: b)), [
        'a>b',
        'b>hotel',
      ]);
    });

    test('drops nothing while the stop stays on its day', () {
      expect(
        transportsDroppedByDraft(route, StopDraft.of(b), stop: b),
        isEmpty,
      );
    });
  });

  group('defaultDayForNewStop', () {
    test('uses the day being viewed', () {
      final route = TripRoute(stops: [testStop('a', day: 2)]);

      expect(defaultDayForNewStop(route, viewDay: 1), 1);
    });

    test('continues the last day with stops in the whole trip', () {
      final route = TripRoute(
        stops: [testStop('a'), testStop('b', day: 3), testStop('c', day: 2)],
      );

      expect(defaultDayForNewStop(route), 3);
    });

    test('starts from day 1 in an empty trip', () {
      expect(defaultDayForNewStop(TripRoute()), 1);
    });
  });

  test('stays another night with the name, place and notes', () {
    final hotel = testLodging(
      'hotel',
      day: 1,
      order: 3,
    ).copyWith(description: '바다 전망', memo: '현관 비밀번호 1234');

    final again = stayAnotherNight(hotel, id: 'hotel-2', day: 2, order: 4);

    expect(again.id, 'hotel-2');
    expect((again.day, again.order), (2, 4));
    expect(again.isSamePlaceAs(hotel), isTrue);
    expect(again.name, hotel.name);
    expect(again.kind, StopKind.lodging);
    expect(again.description, '바다 전망');
    // 메모는 두 밤 모두 필요해서 복사한다.
    expect(again.memo, '현관 비밀번호 1234');
    expect(again.plannedTime, isNull);
  });
}

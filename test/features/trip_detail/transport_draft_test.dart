import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/features/trip_detail/transport_draft.dart';

const _segment = Segment(
  id: 's',
  tripId: 't',
  fromStopId: 'a',
  toStopId: 'b',
  legs: [
    TransportLeg(TransportMode.subway, stopCount: 2),
    TransportLeg(TransportMode.walk, duration: Duration(minutes: 5)),
    TransportLeg(
      TransportMode.flight,
      duration: Duration(hours: 3, minutes: 20),
    ),
    TransportLeg(TransportMode.ferry, duration: Duration(hours: 2)),
  ],
);

void main() {
  test('only subway and bus count stops', () {
    expect(TransportMode.values.where(countsStops), [
      TransportMode.subway,
      TransportMode.bus,
    ]);
  });

  group('fields from saved legs', () {
    test('fill stops, hours and minutes, leaving zero parts empty', () {
      expect(TransportDraft.of(_segment).legs, const [
        LegDraft(TransportMode.subway, stops: '2'),
        LegDraft(TransportMode.walk, minutes: '5'),
        LegDraft(TransportMode.flight, hours: '3', minutes: '20'),
        LegDraft(TransportMode.ferry, hours: '2'),
      ]);
    });

    test('turn back into the same legs', () {
      expect(TransportDraft.of(_segment).toLegs(), _segment.legs);
    });

    test('an undecided segment has no legs', () {
      const undecided = Segment(
        id: 's',
        tripId: 't',
        fromStopId: 'a',
        toStopId: 'b',
      );
      expect(TransportDraft.of(undecided).legs, isEmpty);
      expect(TransportDraft.of(undecided).toLegs(), isEmpty);
    });
  });

  group('saved leg', () {
    test('leaves empty fields out', () {
      expect(
        const LegDraft(TransportMode.bus).toLeg(),
        const TransportLeg(TransportMode.bus),
      );
    });

    test('adds hours and minutes into one duration', () {
      expect(
        const LegDraft(TransportMode.train, hours: '1', minutes: '05').toLeg(),
        const TransportLeg(
          TransportMode.train,
          duration: Duration(hours: 1, minutes: 5),
        ),
      );
    });

    test('has no duration when the time adds up to zero', () {
      expect(
        const LegDraft(TransportMode.car, hours: '0', minutes: '00').toLeg(),
        const TransportLeg(TransportMode.car),
      );
    });

    test('drops stops for modes that do not count them', () {
      // 지하철에서 도보로 바꾸면 적어 둔 정류장 수는 저장하지 않는다.
      expect(
        const LegDraft(TransportMode.walk, stops: '3').toLeg(),
        const TransportLeg(TransportMode.walk),
      );
    });
  });

  group('validation', () {
    test('accepts empty fields', () {
      expect(const LegDraft(TransportMode.subway).isValid, isTrue);
    });

    test('stops are 1 to 99', () {
      expect(const LegDraft(TransportMode.bus, stops: '1').stopsValid, isTrue);
      expect(const LegDraft(TransportMode.bus, stops: '99').stopsValid, isTrue);
      expect(const LegDraft(TransportMode.bus, stops: '0').stopsValid, isFalse);
      expect(
        const LegDraft(TransportMode.bus, stops: '100').stopsValid,
        isFalse,
      );
    });

    test('ignores stops of modes that do not count them', () {
      expect(const LegDraft(TransportMode.walk, stops: '0').isValid, isTrue);
    });

    test('minutes are 0 to 59', () {
      expect(
        const LegDraft(TransportMode.walk, minutes: '59').minutesValid,
        isTrue,
      );
      expect(
        const LegDraft(TransportMode.walk, minutes: '60').minutesValid,
        isFalse,
      );
    });

    test('hours are 0 to 99', () {
      expect(
        const LegDraft(TransportMode.flight, hours: '99').hoursValid,
        isTrue,
      );
      expect(
        const LegDraft(TransportMode.flight, hours: '100').hoursValid,
        isFalse,
      );
    });

    test('a draft is valid only when every leg is', () {
      expect(
        const TransportDraft([
          LegDraft(TransportMode.subway, stops: '2'),
          LegDraft(TransportMode.walk, minutes: '75'),
        ]).isValid,
        isFalse,
      );
    });

    test('takes at most five legs', () {
      final five = TransportDraft(
        List.filled(TransportDraft.maxLegs, const LegDraft(TransportMode.walk)),
      );
      expect(five.isValid, isTrue);
      expect(five.canAddLeg, isFalse);
      expect(
        TransportDraft([
          ...five.legs,
          const LegDraft(TransportMode.walk),
        ]).isValid,
        isFalse,
      );
    });
  });

  test('drafts with the same fields are equal', () {
    expect(
      const TransportDraft([LegDraft(TransportMode.bus, stops: '3')]),
      const TransportDraft([LegDraft(TransportMode.bus, stops: '3')]),
    );
    expect(
      const TransportDraft([LegDraft(TransportMode.bus, stops: '3')]),
      isNot(const TransportDraft([LegDraft(TransportMode.bus, stops: '4')])),
    );
  });
}

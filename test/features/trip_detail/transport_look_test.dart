import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/features/trip_detail/transport_look.dart';

List<TransportLeg> _legs(List<TransportMode> modes) => [
  for (final mode in modes) TransportLeg(mode),
];

void main() {
  test('gives every mode its own icon', () {
    final icons = TransportMode.values.map(transportIcon).toSet();
    expect(icons, hasLength(TransportMode.values.length));
  });

  group('representative mode', () {
    test('is null when no transport is chosen', () {
      expect(representativeMode(const []), isNull);
    });

    test('is the only mode of a single leg', () {
      for (final mode in TransportMode.values) {
        expect(representativeMode(_legs([mode])), mode);
      }
    });

    test('prefers the ride over walking', () {
      expect(
        representativeMode(
          _legs([TransportMode.walk, TransportMode.subway, TransportMode.walk]),
        ),
        TransportMode.subway,
      );
    });

    test('prefers far-reaching modes regardless of order', () {
      expect(
        representativeMode(_legs([TransportMode.subway, TransportMode.flight])),
        TransportMode.flight,
      );
      expect(
        representativeMode(_legs([TransportMode.bus, TransportMode.subway])),
        TransportMode.subway,
      );
      expect(
        representativeMode(_legs([TransportMode.car, TransportMode.ferry])),
        TransportMode.ferry,
      );
    });

    test('ignores durations so editing minutes does not change it', () {
      expect(
        representativeMode(const [
          TransportLeg(TransportMode.walk, duration: Duration(hours: 2)),
          TransportLeg(TransportMode.bus, duration: Duration(minutes: 5)),
        ]),
        TransportMode.bus,
      );
    });
  });

  group('line style', () {
    test('dots walking', () {
      expect(lineStyleOf(TransportMode.walk), MapLineStyle.dotted);
    });

    test('dashes crossing the sky and the sea', () {
      expect(lineStyleOf(TransportMode.flight), MapLineStyle.dashed);
      expect(lineStyleOf(TransportMode.ferry), MapLineStyle.dashed);
    });

    test('keeps rides on roads and rails solid', () {
      for (final mode in [
        TransportMode.subway,
        TransportMode.bus,
        TransportMode.train,
        TransportMode.car,
      ]) {
        expect(lineStyleOf(mode), MapLineStyle.solid, reason: '$mode');
      }
    });

    test('keeps undecided segments solid like before', () {
      expect(lineStyleOf(null), MapLineStyle.solid);
    });
  });
}

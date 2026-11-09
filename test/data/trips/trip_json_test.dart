import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/core/time/local_time.dart';
import 'package:mapmarker_app/data/models/map_provider_type.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/trip_json.dart';

/// 서버 응답(TripResponse)과 같은 모양.
Map<String, Object?> serverTrip({
  String id = 'trip-1',
  Object? dates = const {'start': '2026-10-15', 'end': '2026-10-17'},
  String updatedAt = '2026-10-15T03:00:00.000Z',
}) => {
  'id': id,
  'title': '부산 2박 3일 가을 여행',
  'region': '부산',
  'nights': 2,
  'season': 'autumn',
  'dates': dates,
  'phaseOverride': 'during',
  'mapProvider': 'naver',
  'origin': 'manual',
  'copiedFromTripId': null,
  'shareId': null,
  'createdAt': '2026-10-14T03:00:00.000Z',
  'updatedAt': updatedAt,
};

/// 서버 응답(StopResponse)과 같은 모양.
Map<String, Object?> serverStop({
  String id = 'stop-1',
  int day = 1,
  int order = 0,
}) => {
  'id': id,
  'tripId': 'trip-1',
  'day': day,
  'order': order,
  'latitude': 35.1587,
  'longitude': 129,
  'name': '해운대',
  'kind': 'tour',
  'description': '바다',
  'memo': '',
  'plannedTime': '09:30',
  'visited': false,
  'visitedAt': null,
  'timeZone': 'Asia/Seoul',
  'placeProvider': 'naver',
  'placeId': '12345',
};

/// 서버 응답(SegmentResponse)과 같은 모양.
Map<String, Object?> serverSegment({
  String id = 'seg-1',
  String from = 'stop-1',
  String to = 'stop-2',
}) => {
  'id': id,
  'tripId': 'trip-1',
  'fromStopId': from,
  'toStopId': to,
  'legs': [
    {'mode': 'subway', 'stopCount': 4, 'durationMinutes': 25},
    {'mode': 'walk'},
  ],
  'curvature': 0,
  'type': 'gpsTrack',
};

Trip _trip({TripDates? dates, TripPhase? phaseOverride}) => Trip(
  id: 'trip-1',
  title: '부산 2박 3일 가을 여행',
  region: '부산',
  nights: 2,
  season: Season.autumn,
  dates: dates,
  phaseOverride: phaseOverride,
  createdAt: DateTime.utc(2026, 10, 14),
  updatedAt: DateTime.utc(2026, 10, 15),
);

Stop _stop({LocalTime? plannedTime}) => Stop(
  id: 'stop-1',
  tripId: 'trip-1',
  latitude: 35.1587,
  longitude: 129.1604,
  name: '해운대',
  day: 2,
  order: 1,
  kind: StopKind.lodging,
  description: '설명',
  memo: '메모',
  plannedTime: plannedTime,
);

void main() {
  group('trip', () {
    test('reads every field the server sends', () {
      final trip = tripFromJson(serverTrip());

      expect(trip.id, 'trip-1');
      expect(trip.title, '부산 2박 3일 가을 여행');
      expect(trip.region, '부산');
      expect(trip.nights, 2);
      expect(trip.season, Season.autumn);
      expect(
        trip.dates,
        TripDates(LocalDate(2026, 10, 15), LocalDate(2026, 10, 17)),
      );
      expect(trip.phaseOverride, TripPhase.during);
      expect(trip.mapProvider, MapProviderType.naver);
      expect(trip.origin, TripOrigin.manual);
      expect(trip.createdAt, DateTime.utc(2026, 10, 14, 3));
      expect(trip.createdAt.isUtc, isTrue);
      expect(trip.updatedAt, DateTime.utc(2026, 10, 15, 3));
    });

    test('reads a trip without dates', () {
      expect(tripFromJson(serverTrip(dates: null)).dates, isNull);
    });

    test('creates without the fields the server decides', () {
      final json = createTripJson(
        _trip(
          dates: TripDates(LocalDate(2026, 10, 15), LocalDate(2026, 10, 17)),
        ),
      );

      expect(json, {
        'id': 'trip-1',
        'title': '부산 2박 3일 가을 여행',
        'region': '부산',
        'nights': 2,
        'season': 'autumn',
        'dates': {'start': '2026-10-15', 'end': '2026-10-17'},
        'phaseOverride': null,
        'mapProvider': null,
      });
    });

    test('updates with nulls so cleared fields are cleared on the server', () {
      final json = updateTripJson(_trip());

      expect(json, {
        'title': '부산 2박 3일 가을 여행',
        'region': '부산',
        'nights': 2,
        'season': 'autumn',
        'dates': null,
        'phaseOverride': null,
        'mapProvider': null,
      });
    });
  });

  group('stop', () {
    test('reads every field the server sends', () {
      final stop = stopFromJson(serverStop());

      expect(stop.id, 'stop-1');
      expect(stop.tripId, 'trip-1');
      expect(stop.day, 1);
      expect(stop.order, 0);
      expect(stop.latitude, 35.1587);
      // JSON의 정수 좌표도 실수로 읽는다.
      expect(stop.longitude, 129.0);
      expect(stop.name, '해운대');
      expect(stop.kind, StopKind.tour);
      expect(stop.description, '바다');
      expect(stop.memo, '');
      expect(stop.plannedTime, const LocalTime(9, 30));
      expect(stop.visited, isFalse);
      expect(stop.visitedAt, isNull);
      expect(stop.timeZone, 'Asia/Seoul');
      expect(stop.placeProvider, MapProviderType.naver);
      expect(stop.placeId, '12345');
    });

    test('reads a visit time as UTC', () {
      final stop = stopFromJson({
        ...serverStop(),
        'visited': true,
        'visitedAt': '2026-10-15T01:30:00.000Z',
      });

      expect(stop.visitedAt, DateTime.utc(2026, 10, 15, 1, 30));
    });

    test('creates with its place in the route', () {
      final json = createStopJson(_stop(plannedTime: const LocalTime(9, 5)));

      expect(json, {
        'id': 'stop-1',
        'day': 2,
        'order': 1,
        'latitude': 35.1587,
        'longitude': 129.1604,
        'name': '해운대',
        'kind': 'lodging',
        'description': '설명',
        'memo': '메모',
        'plannedTime': '09:05',
        'timeZone': 'Asia/Seoul',
        'placeProvider': null,
        'placeId': null,
      });
    });

    test(
      'updates without day and order, clearing the planned time with null',
      () {
        final json = updateStopJson(_stop());

        expect(json.containsKey('day'), isFalse);
        expect(json.containsKey('order'), isFalse);
        expect(json.containsKey('id'), isFalse);
        expect(json['plannedTime'], isNull);
        expect(json.containsKey('plannedTime'), isTrue);
        expect(json['name'], '해운대');
      },
    );
  });

  group('segment', () {
    test('reads legs with minutes as durations', () {
      final segment = segmentFromJson(serverSegment());

      expect(segment.id, 'seg-1');
      expect(segment.fromStopId, 'stop-1');
      expect(segment.toStopId, 'stop-2');
      expect(segment.legs, const [
        TransportLeg(
          TransportMode.subway,
          stopCount: 4,
          duration: Duration(minutes: 25),
        ),
        TransportLeg(TransportMode.walk),
      ]);
      expect(segment.curvature, 0.0);
      expect(segment.type, SegmentType.gpsTrack);
    });

    test('updates only what the server lets the app change', () {
      final json = updateSegmentJson(
        const Segment(
          id: 'seg-1',
          tripId: 'trip-1',
          fromStopId: 'stop-1',
          toStopId: 'stop-2',
          legs: [
            TransportLeg(
              TransportMode.bus,
              stopCount: 3,
              duration: Duration(hours: 1, minutes: 5),
            ),
            TransportLeg(TransportMode.walk),
          ],
          curvature: 0.4,
        ),
      );

      // 비운 정류장 수·시간은 null이 아니라 빼고 보낸다(서버가 null을 받지 않는다).
      expect(json, {
        'legs': [
          {'mode': 'bus', 'stopCount': 3, 'durationMinutes': 65},
          {'mode': 'walk'},
        ],
        'curvature': 0.4,
        'type': 'normal',
      });
    });
  });

  group('trip detail', () {
    test('reads the trip with its whole route in route order', () {
      final detail = tripDetailFromJson({
        'trip': serverTrip(),
        'stops': [
          serverStop(id: 'stop-2', day: 2),
          serverStop(id: 'stop-1', day: 1),
        ],
        'segments': [serverSegment()],
      });

      expect(detail.trip.id, 'trip-1');
      expect(
        [for (final stop in detail.route.stops) stop.id],
        ['stop-1', 'stop-2'],
      );
      expect(detail.route.segments.single.id, 'seg-1');
    });
  });

  group('broken responses', () {
    test('throw FormatException instead of a type error', () {
      for (final json in <Map<String, Object?>>[
        {...serverTrip(), 'nights': '2'},
        {...serverTrip(), 'season': 'monsoon'},
        {
          ...serverTrip(),
          'dates': {'start': '2026-10-15'},
        },
        {...serverTrip(), 'updatedAt': 'yesterday'},
        <String, Object?>{},
      ]) {
        expect(
          () => tripFromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
      expect(
        () => stopFromJson({...serverStop(), 'plannedTime': '9:30'}),
        throwsFormatException,
      );
      expect(
        () => segmentFromJson({...serverSegment(), 'legs': 'walk'}),
        throwsFormatException,
      );
      expect(() => tripDetailFromJson('<html>'), throwsFormatException);
    });
  });
}

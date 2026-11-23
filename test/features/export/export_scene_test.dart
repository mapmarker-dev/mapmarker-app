import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/theme/app_colors.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/core/theme/app_tokens.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/photo.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/models/trip_route.dart';
import 'package:mapmarker_app/data/trips/route_links.dart';
import 'package:mapmarker_app/features/export/export_scene.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_stops.dart';

final _colors = AppTheme.light().extension<AppColors>()!;

TripRoute _route(List<Stop> stops) => TripRoute(
  stops: stops,
  segments: linkStops(
    tripId: 'trip',
    stops: TripRoute(stops: stops).stops,
    existing: const [],
  ),
);

const _photo = Photo(
  id: 'p',
  url: 'https://s3/p',
  thumbnailUrl: 'https://s3/t',
);

Stop _visited(Stop stop) =>
    stop.copyWith(visitedAt: () => DateTime.utc(2026, 10, 20, 3));

final _trip = testTrip(
  id: 'trip',
  region: '제주',
  dates: TripDates(LocalDate(2026, 10, 20), LocalDate(2026, 10, 22)),
);

ExportScene _scene(
  TripRoute route, {
  TripPhase phase = TripPhase.before,
  ExportOptions options = const ExportOptions(),
  Trip? trip,
}) => buildExportScene(
  trip: trip ?? _trip,
  route: route,
  phase: phase,
  options: options,
  colors: _colors,
  l10n: testL10n,
  photoOf: (photo) => NetworkImage(photo.thumbnailUrl),
);

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  // 1일차: 용두암 > 동문시장 > 숙소, 2일차: 성산 > 섭지코지 > 숙소(같은 자리)
  final airport = testStop('용두암');
  final market = testStop('동문시장', order: 1, kind: StopKind.food);
  final hotel = testLodging('숙소', order: 2);
  final peak = testStop('성산', day: 2);
  final cape = testStop('섭지코지', day: 2, order: 1);
  final hotel2 = testLodging('숙소2', day: 2, order: 2);
  final stops = [airport, market, hotel, peak, cape, hotel2];

  group('before the trip', () {
    late final scene = _scene(_route(stops));

    test('draws the planned route like the app map', () {
      expect(scene.markers.map((m) => m.name), [
        '용두암',
        '동문시장',
        '숙소',
        '성산',
        '섭지코지',
      ]);
      expect(
        scene.lines.map((l) => l.color),
        contains(_colors.routeDay(2).background),
      );
    });

    test('titles the image with the trip title and its period', () {
      expect(scene.title, '‘${_trip.title}’');
      expect(scene.subtitle, testL10n.tripSummaryOf(_trip));
      expect(scene.legendDays, [1, 2]);
    });

    test('a day range shows that day and its date', () {
      final day = _scene(_route(stops), options: const ExportOptions(day: 2));

      // 2일차 보기는 전날 숙소에서 출발한다(동선 화면과 같다).
      expect(day.markers.map((m) => m.name), ['숙소', '성산', '섭지코지']);
      expect(day.subtitle, '2일차, 10월 21일 (수)');
      expect(day.legendDays, isEmpty);
    });

    test('leaves out the title card when the title is off', () {
      final untitled = _scene(
        _route(stops),
        options: const ExportOptions(title: false),
      );

      expect(untitled.title, isNull);
    });

    test('hiding lodging hides lodging markers and their lines', () {
      final noLodging = _scene(
        _route(stops),
        options: const ExportOptions(lodging: false),
      );

      expect(noLodging.markers.map((m) => m.name), isNot(contains('숙소')));
      // 하루가 숙소에서 끝나 다음 날로 넘어가는 곳은 잇지 않는다.
      expect(noLodging.lines.length, scene.lines.length - 3);
    });

    test('joins places around a lodging visited during the day faintly', () {
      final noonHotel = testLodging('숙소', order: 1);
      final route = _route([airport, noonHotel, market.copyWith(order: 2)]);

      final noLodging = _scene(
        route,
        options: const ExportOptions(lodging: false),
      );

      expect(noLodging.lines.single.style, MapLineStyle.faint);
    });
  });

  group('visits', () {
    // 1일차 두 곳만 방문했다.
    final route = _route([
      _visited(airport),
      _visited(market),
      hotel,
      peak,
      cape,
      hotel2,
    ]);

    for (final phase in TripPhase.values) {
      test('leave the route as planned ${phase.name} the trip', () {
        final scene = _scene(route, phase: phase);
        final plan = _scene(_route(stops), phase: phase);

        // 동선의 순서와 장소가 먼저라서 방문 여부와 관계없이 모두 같은 모양이다(흐림, 체크 표시 없음).
        expect(
          scene.markers.map((m) => m.look),
          plan.markers.map((m) => m.look),
        );
        // 구간 ID는 동선마다 새로 만들어져서 그리는 모양만 비교한다.
        String drawn(MapLine l) =>
            '${l.color} ${l.outline} ${l.style} ${l.points}';
        expect(scene.lines.map(drawn), plan.lines.map(drawn));
        expect(scene.arrows.length, plan.arrows.length);
        expect(scene.subtitle, testL10n.tripSummaryOf(_trip));
      });
    }
  });

  group('after the trip', () {
    final withPhotos = [
      airport.copyWith(photo: () => _photo),
      market,
      hotel,
      peak.copyWith(photo: () => _photo),
      cape,
      hotel2,
    ];

    test('enlarges photo markers a little and counts photos', () {
      final scene = _scene(_route(withPhotos), phase: TripPhase.after);
      final large = scene.markers.where((m) => m.large).map((m) => m.name);

      expect(large, ['용두암', '성산']);
      // 사진이 없는 장소도 번호 마커 그대로다.
      expect(scene.markers.where((m) => !m.large).map((m) => m.look.label), [
        '2',
        null,
        '2',
      ]);
      expect(scene.subtitle, '2026.10.20 – 10.22, 2박 3일, 사진 2장');
      expect(scene.hasPhotos, isTrue);
    });

    test('keeps photo markers at map size before the trip', () {
      final scene = _scene(_route(withPhotos));

      expect(scene.markers.where((m) => m.look.photo != null), hasLength(2));
      expect(scene.markers.where((m) => m.large), isEmpty);
      expect(scene.subtitle, testL10n.tripSummaryOf(_trip));
    });

    test('without photos it keeps the plain route', () {
      final scene = _scene(
        _route(withPhotos),
        phase: TripPhase.after,
        options: const ExportOptions(photos: false),
      );

      expect(scene.markers.where((m) => m.look.photo != null), isEmpty);
      expect(scene.markers.where((m) => m.large), isEmpty);
      expect(scene.subtitle, testL10n.tripSummaryOf(_trip));
      expect(scene.hasPhotos, isTrue, reason: '켜면 넣을 사진이 있다');
    });
  });

  group('map frame', () {
    test('leaves room above the places for the title card and markers', () {
      final scene = _scene(_route(stops));

      final frame = scene.frameFor(titleBottom: 80)!;

      expect(frame.padding.top, 80 + AppSpace.md + scene.headroom);
      expect(scene.frameFor()!.padding.top, AppSpace.md + scene.headroom);
      expect(frame.bounds, isNotNull);
    });

    test('large photos need more room', () {
      final plain = _scene(_route(stops), phase: TripPhase.after);
      final photos = _scene(
        _route([airport.copyWith(photo: () => _photo), ...stops.skip(1)]),
        phase: TripPhase.after,
      );

      expect(photos.headroom, greaterThan(plain.headroom));
    });

    test('has no frame without places', () {
      final empty = _scene(_route(stops), options: const ExportOptions(day: 3));

      expect(empty.markers, isEmpty);
      expect(empty.frameFor(), isNull);
    });
  });
}

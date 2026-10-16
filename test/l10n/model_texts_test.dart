import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/data/models/segment.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

final l10n = lookupAppLocalizations(appLocale);

Segment _segment(List<TransportLeg> legs) => Segment(
  id: 'segment-1',
  tripId: 'trip-1',
  fromStopId: 'stop-1',
  toStopId: 'stop-2',
  legs: legs,
);

Trip _trip({TripDates? dates, int nights = 1}) {
  final now = DateTime.utc(2026, 10, 1);
  return Trip(
    id: 'trip-1',
    title: '가족 여행',
    region: '부산',
    nights: dates?.nights ?? nights,
    season: Season.spring,
    dates: dates,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // 앱에서는 Material 다국어가 날짜 형식 데이터를 불러온다. 위젯 없이 돌리는 테스트라 직접 부른다.
  setUpAll(() => initializeDateFormatting(appLocale.languageCode));

  group('상태와 계절', () {
    test('names each phase', () {
      expect(TripPhase.values.map(l10n.tripPhaseName), [
        '여행 전',
        '여행 중',
        '여행 후',
      ]);
    });

    test('names each season', () {
      expect(Season.values.map(l10n.seasonName), ['봄', '여름', '가을', '겨울']);
    });
  });

  test('names each kind of stop', () {
    expect(StopKind.values.map(l10n.stopKindName), ['숙소', '음식', '관광', '기타']);
  });

  group('일정', () {
    test('writes a day trip as 당일치기', () {
      expect(l10n.nightsText(0), '당일치기');
    });

    test('writes n nights as n박 n+1일', () {
      expect(l10n.nightsText(1), '1박 2일');
      expect(l10n.nightsText(2), '2박 3일');
      expect(l10n.nightsText(10), '10박 11일');
    });
  });

  group('기본 제목', () {
    test('puts region, length, season and 여행 together', () {
      expect(
        l10n.defaultTripTitle(region: '부산', nights: 2, season: Season.spring),
        '부산 2박 3일 봄 여행',
      );
      expect(
        l10n.defaultTripTitle(region: '경주', nights: 0, season: Season.autumn),
        '경주 당일치기 가을 여행',
      );
    });

    test('trims the region', () {
      expect(
        l10n.defaultTripTitle(
          region: '  제주 ',
          nights: 3,
          season: Season.summer,
        ),
        '제주 3박 4일 여름 여행',
      );
    });

    test('leaves out parts not chosen yet', () {
      expect(l10n.defaultTripTitle(region: '', nights: 1), '1박 2일 여행');
      expect(l10n.defaultTripTitle(region: '강릉', nights: 1), '강릉 1박 2일 여행');
      expect(
        l10n.defaultTripTitle(region: '', nights: 1, season: Season.winter),
        '1박 2일 겨울 여행',
      );
    });

    test('builds the default title of a trip', () {
      expect(l10n.defaultTitleOf(_trip(nights: 2)), '부산 2박 3일 봄 여행');
    });
  });

  group('기간', () {
    test('writes dates in the same year', () {
      expect(
        l10n.tripDatesText(
          TripDates(LocalDate(2026, 10, 4), LocalDate(2026, 10, 7)),
        ),
        '2026.10.04 – 10.07',
      );
    });

    test('writes both years across the new year', () {
      expect(
        l10n.tripDatesText(
          TripDates(LocalDate(2026, 12, 30), LocalDate(2027, 1, 2)),
        ),
        '2026.12.30 – 2027.01.02',
      );
    });

    test('writes a day trip as one date', () {
      expect(
        l10n.tripDatesText(
          TripDates(LocalDate(2026, 10, 4), LocalDate(2026, 10, 4)),
        ),
        '2026.10.04',
      );
    });

    test('sums up dates and length for the list', () {
      expect(
        l10n.tripSummaryOf(
          _trip(
            dates: TripDates(LocalDate(2026, 10, 14), LocalDate(2026, 10, 17)),
          ),
        ),
        '2026.10.14 – 10.17 · 3박 4일',
      );
      expect(l10n.tripSummaryOf(_trip()), '날짜 미정 · 1박 2일');
    });
  });

  group('이동 수단', () {
    test('writes a leg with stops or duration', () {
      String leg(TransportMode mode, {int? stops, Duration? duration}) =>
          l10n.transportLegText(
            TransportLeg(mode, stopCount: stops, duration: duration),
          );

      expect(leg(TransportMode.subway, stops: 4), '지하철 4정류장');
      expect(leg(TransportMode.bus, stops: 3), '버스 3정류장');
      expect(
        leg(TransportMode.walk, duration: const Duration(minutes: 20)),
        '도보 20분',
      );
      expect(
        leg(
          TransportMode.flight,
          duration: const Duration(hours: 3, minutes: 20),
        ),
        '비행기 3시간 20분',
      );
      expect(
        leg(
          TransportMode.ferry,
          duration: const Duration(hours: 1, minutes: 40),
        ),
        '배 1시간 40분',
      );
      expect(
        leg(TransportMode.train, duration: const Duration(hours: 2)),
        '기차 2시간',
      );
      expect(leg(TransportMode.walk), '도보');
    });

    test('names every mode', () {
      expect(TransportMode.values.map(l10n.transportModeName), [
        '도보',
        '지하철',
        '버스',
        '기차',
        '차',
        '비행기',
        '배',
      ]);
    });

    test('joins transfers with +', () {
      expect(
        l10n.transportText(
          _segment(const [
            TransportLeg(TransportMode.subway, stopCount: 2),
            TransportLeg(TransportMode.walk),
          ]),
        ),
        '지하철 2정류장 + 도보',
      );
      expect(
        l10n.transportText(
          _segment(const [
            TransportLeg(TransportMode.bus, stopCount: 1),
            TransportLeg(TransportMode.walk),
          ]),
        ),
        '버스 1정류장 + 도보',
      );
    });

    test('is empty when no transport is chosen', () {
      expect(l10n.transportText(_segment(const [])), isEmpty);
    });
  });
}

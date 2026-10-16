import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/router.dart';
import 'package:mapmarker_app/core/time/today.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

/// 테스트의 지금. 오늘은 2026-10-15다.
final testNow = DateTime(2026, 10, 15, 12);

/// 앱과 같은 언어의 글자.
final testL10n = lookupAppLocalizations(appLocale);

/// 앱과 같은 언어 설정의 [MaterialApp.router].
Widget testMaterialApp(RouterConfig<Object> routerConfig) => MaterialApp.router(
  locale: appLocale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  routerConfig: routerConfig,
);

/// 기본 제목을 단 여행. 기간이 있으면 일정과 계절을 기간에 맞춘다.
Trip testTrip({
  required String id,
  String region = '부산',
  TripDates? dates,
  int nights = 1,
  Season season = Season.spring,
  TripPhase? phaseOverride,
  DateTime? updatedAt,
}) {
  final tripNights = dates?.nights ?? nights;
  final tripSeason = dates?.season ?? season;
  final at = updatedAt ?? testNow.toUtc();
  return Trip(
    id: id,
    title: testL10n.defaultTripTitle(
      region: region,
      nights: tripNights,
      season: tripSeason,
    ),
    region: region,
    nights: tripNights,
    season: tripSeason,
    dates: dates,
    phaseOverride: phaseOverride,
    createdAt: at,
    updatedAt: at,
  );
}

/// 시각을 [testNow]로 고정한 메모리 저장소.
MemoryTripRepository testRepository([List<Trip> trips = const []]) {
  final repository = MemoryTripRepository(clock: () => testNow, seed: trips);
  addTearDown(repository.dispose);
  return repository;
}

/// 앱과 같은 경로 표와 로캘로 띄운다. 시각은 [testNow]로 고정한다.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester, {
  required TripRepository repository,
  String? location,
}) async {
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => testNow),
      tripRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final router = container.read(routerProvider);
  if (location != null) router.go(location);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: testMaterialApp(router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

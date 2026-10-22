import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/router.dart';
import 'package:mapmarker_app/core/links/open_link.dart';
import 'package:mapmarker_app/core/map/map_registry.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/core/time/today.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

import 'fake_map.dart';

/// 테스트의 지금. 오늘은 2026-10-15다.
final testNow = DateTime(2026, 10, 15, 12);

/// 앱과 같은 언어의 글자.
final testL10n = lookupAppLocalizations(appLocale);

/// 앱과 같은 테마와 언어 설정의 [MaterialApp.router].
Widget testMaterialApp(RouterConfig<Object> routerConfig) => MaterialApp.router(
  theme: AppTheme.light(),
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

/// 휴대폰 세로 화면(412×915)으로 만든다.
///
/// 테스트 기본 화면(800×600)은 가로이고 폭이 600 이상이라, 동선 페이지가 일차 동선 목록을 오른쪽 패널로 띄운다.
/// 아래 시트를 보는 테스트는 이 화면에서 띄운다.
void usePortraitPhone(WidgetTester tester) {
  tester.view.physicalSize =
      const Size(412, 915) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
}

/// 아래에 시스템 내비게이션 막대(3버튼, [height] 논리 px)가 화면을 가리는 기기로 만든다.
void showNavigationBar(WidgetTester tester, {double height = 48}) {
  final padding = FakeViewPadding(
    bottom: height * tester.view.devicePixelRatio,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

/// 시각을 [testNow]로 고정한 메모리 저장소. 구간은 [stops] 사이에 저장소가 잇는다.
MemoryTripRepository testRepository([
  List<Trip> trips = const [],
  List<Stop> stops = const [],
]) {
  final repository = MemoryTripRepository(
    clock: () => testNow,
    seed: trips,
    seedStops: stops,
  );
  addTearDown(repository.dispose);
  return repository;
}

/// 링크를 열지 못하는 기기. 테스트에서 실제 앱이나 브라우저를 열지 않게 기본으로 쓴다.
Future<bool> refuseLinks(Uri uri) async => false;

/// 앱과 같은 경로 표와 로캘로 띄운다. 시각은 [testNow]로 고정하고, 지도는 가짜 지도([FakeMap])다.
/// 앱 밖으로 여는 링크는 [openLink]가 받는다.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester, {
  required TripRepository repository,
  String? location,
  OpenLink openLink = refuseLinks,
}) async {
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => testNow),
      tripRepositoryProvider.overrideWithValue(repository),
      mapProviderProvider.overrideWith((ref, type) => const FakeMapProvider()),
      openLinkProvider.overrideWithValue(openLink),
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

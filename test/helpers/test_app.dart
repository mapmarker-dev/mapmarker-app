import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/router.dart';
import 'package:mapmarker_app/core/links/open_link.dart';
import 'package:mapmarker_app/core/map/map_registry.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';
import 'package:mapmarker_app/core/time/today.dart';
import 'package:mapmarker_app/data/api/api_client.dart';
import 'package:mapmarker_app/data/auth/auth_api.dart';
import 'package:mapmarker_app/data/auth/auth_session.dart';
import 'package:mapmarker_app/data/auth/social_sdk.dart';
import 'package:mapmarker_app/data/models/candidate.dart';
import 'package:mapmarker_app/data/models/stop.dart';
import 'package:mapmarker_app/data/models/trip.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';
import 'package:mapmarker_app/l10n/l10n.dart';

import 'fake_auth.dart';
import 'fake_http.dart';
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
  List<Candidate> candidates = const [],
]) {
  final repository = MemoryTripRepository(
    clock: () => testNow,
    seed: trips,
    seedStops: stops,
    seedCandidates: candidates,
  );
  addTearDown(repository.dispose);
  return repository;
}

/// 동선 페이지의 일차 칩이나 숙소·후보 칩을 누른다. 칩은 글자가 아니라 칩 전체가 눌린다.
/// 칩 줄은 가로로 넘어가서, 화면 밖 칩은 먼저 보이게 넘긴다.
Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ChoiceChip || w is FilterChip),
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// 링크를 열지 못하는 기기. 테스트에서 실제 앱이나 브라우저를 열지 않게 기본으로 쓴다.
Future<bool> refuseLinks(Uri uri) async => false;

/// 로그인 상태와 서버·소셜 SDK를 가짜로 바꾸는 덮어쓰기. 실제 서버에 붙지 않는다.
/// [authServer]는 로그인·재발급·로그아웃 요청과, 저장소를 덮어쓰지 않았을 때의 여행 API 요청에 답한다.
List<Override> authOverrides({
  AuthSession? session,
  SocialSdk? socialSdk,
  FakeHttp? authServer,
}) {
  final server = authServer ?? fakeAuthServer();
  final authSession = session ?? testSession(http: server);
  return [
    authSessionProvider.overrideWithValue(authSession),
    authApiProvider.overrideWithValue(AuthApi(fakeDio(server))),
    apiClientProvider.overrideWithValue(
      ApiClient(fakeDio(server), authSession),
    ),
    socialSdkProvider.overrideWithValue(socialSdk ?? FakeSocialSdk()),
  ];
}

/// 앱과 같은 경로 표와 로캘로 띄운다. 시각은 [testNow]로 고정하고, 지도는 가짜 지도([FakeMap])다.
/// 앱 밖으로 여는 링크는 [openLink]가 받는다.
///
/// 기본으로 로그인 상태다. 로그인 화면은 [session]에 `testSession(loggedIn: false)`를 넘겨 띄운다.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester, {
  required TripRepository repository,
  String? location,
  OpenLink openLink = refuseLinks,
  AuthSession? session,
  SocialSdk? socialSdk,
  FakeHttp? authServer,
}) async {
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => testNow),
      tripRepositoryProvider.overrideWithValue(repository),
      mapProviderProvider.overrideWith((ref, type) => const FakeMapProvider()),
      openLinkProvider.overrideWithValue(openLink),
      ...authOverrides(
        session: session,
        socialSdk: socialSdk,
        authServer: authServer,
      ),
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

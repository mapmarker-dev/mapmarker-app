import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/router.dart';
import 'package:mapmarker_app/app/routes.dart';
import 'package:mapmarker_app/features/login/login_screen.dart';
import 'package:mapmarker_app/features/trips/trip_list_screen.dart';

import '../helpers/fake_auth.dart';
import '../helpers/test_app.dart';

Widget _app() => ProviderScope(
  overrides: authOverrides(),
  child: Consumer(
    builder: (context, ref, _) => testMaterialApp(ref.watch(routerProvider)),
  ),
);

void main() {
  testWidgets('starts at the trip list', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byType(TripListScreen), findsOneWidget);
    // 테스트는 디버그 모드로 돌아서 검증 화면 진입 버튼이 보인다.
    expect(find.byTooltip('스냅샷 검증'), findsOneWidget);
  });

  testWidgets('builds screens as Material pages', (tester) async {
    await tester.pumpWidget(_app());

    // go_router가 MaterialApp을 알아보지 못하면 전환 애니메이션 없는 페이지로 띄운다
    // (go_router 18 + package:flutter/material.dart 조합).
    final route = ModalRoute.of(tester.element(find.byType(TripListScreen)));
    expect(route?.settings, isA<MaterialPage<void>>());
  });

  test('snapshot lab sits under the trip list in debug builds', () {
    final container = ProviderContainer.test(overrides: authOverrides());
    final router = container.read(routerProvider);

    final match = router.configuration.findMatch(Uri.parse(Routes.snapshotLab));

    // 여행 목록 위에 검증 화면이 쌓인다. 뒤로가기를 누르면 여행 목록으로 간다.
    expect(match.matches.map((m) => m.matchedLocation), [
      Routes.tripList,
      Routes.snapshotLab,
    ]);
  });

  test('trip creation and trip pages sit under the trip list', () {
    final container = ProviderContainer.test(overrides: authOverrides());
    final router = container.read(routerProvider);

    final create = router.configuration.findMatch(Uri.parse(Routes.tripCreate));
    final trip = router.configuration.findMatch(Uri.parse(Routes.trip('abc')));

    expect(create.matches.map((m) => m.matchedLocation), [
      Routes.tripList,
      Routes.tripCreate,
    ]);
    // `new`를 여행 ID로 읽지 않는다.
    expect(create.pathParameters, isEmpty);
    expect(trip.matches.map((m) => m.matchedLocation), [
      Routes.tripList,
      '/trips/abc',
    ]);
    expect(trip.pathParameters['tripId'], 'abc');
  });

  test('login sits at the top, not under the trip list', () {
    final container = ProviderContainer.test(overrides: authOverrides());
    final router = container.read(routerProvider);

    final match = router.configuration.findMatch(Uri.parse(Routes.login));

    // 아래에 두면 토큰 없이 여행 목록이 만들어지고, 뒤로가기가 앱을 닫지 못한다.
    expect(match.matches.map((m) => m.matchedLocation), [Routes.login]);
  });

  group('authRedirect', () {
    String? redirect(String location, {required bool loggedIn}) =>
        authRedirect(Uri.parse(location), loggedIn: loggedIn);

    test('sends a logged-out user from the trip list to login', () {
      expect(redirect('/', loggedIn: false), Routes.login);
    });

    test('remembers a deep link while logging in', () {
      expect(
        redirect('/trips/abc', loggedIn: false),
        '/login?from=%2Ftrips%2Fabc',
      );
    });

    test('keeps a logged-out user on login', () {
      expect(redirect('/login?from=%2Ftrips%2Fabc', loggedIn: false), isNull);
    });

    test('leaves a logged-in user where they are', () {
      expect(redirect('/trips/abc', loggedIn: true), isNull);
    });

    test('sends a logged-in user on login back to where they came from', () {
      expect(
        redirect('/login?from=%2Ftrips%2Fabc', loggedIn: true),
        '/trips/abc',
      );
      expect(redirect('/login', loggedIn: true), Routes.tripList);
    });

    test('only returns to paths inside the app', () {
      for (final from in [
        'https://example.com/x',
        '//example.com/x',
        'example.com',
        '/login',
        '/login?from=%2Ftrips',
        '',
      ]) {
        final location = Uri(
          path: Routes.login,
          queryParameters: {'from': from},
        ).toString();
        expect(
          redirect(location, loggedIn: true),
          Routes.tripList,
          reason: from,
        );
      }
    });
  });

  group('when the login state changes', () {
    testWidgets('logging in opens the trip list', (tester) async {
      final session = testSession(loggedIn: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: authOverrides(session: session),
          child: Consumer(
            builder: (context, ref, _) =>
                testMaterialApp(ref.watch(routerProvider)),
          ),
        ),
      );
      expect(find.byType(LoginScreen), findsOneWidget);

      await session.signIn(testTokens);
      await tester.pumpAndSettle();

      expect(find.byType(TripListScreen), findsOneWidget);
    });

    testWidgets('losing the session opens login', (tester) async {
      final session = testSession();
      await tester.pumpWidget(
        ProviderScope(
          overrides: authOverrides(session: session),
          child: Consumer(
            builder: (context, ref, _) =>
                testMaterialApp(ref.watch(routerProvider)),
          ),
        ),
      );
      expect(find.byType(TripListScreen), findsOneWidget);

      await tester.runAsync(session.logOut);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });
  });
}

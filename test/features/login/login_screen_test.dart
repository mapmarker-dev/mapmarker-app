import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/auth/social_sdk.dart';
import 'package:mapmarker_app/features/login/login_screen.dart';
import 'package:mapmarker_app/features/trips/trip_list_screen.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_http.dart';
import '../../helpers/test_app.dart';

void main() {
  late FakeSocialSdk sdk;

  setUp(() => sdk = FakeSocialSdk());

  Future<void> pumpLogin(WidgetTester tester, {FakeHttp? server}) async {
    final authServer = server ?? fakeAuthServer();
    await pumpTestApp(
      tester,
      repository: testRepository(),
      session: testSession(loggedIn: false, http: authServer),
      socialSdk: sdk,
      authServer: authServer,
    );
  }

  Finder kakaoButton() => find.text(testL10n.loginWithKakao);
  Finder naverButton() => find.text(testL10n.loginWithNaver);

  testWidgets('shows the app name and both login buttons', (tester) async {
    await pumpLogin(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('MapMarker'), findsOneWidget);
    expect(kakaoButton(), findsOneWidget);
    expect(naverButton(), findsOneWidget);
  });

  testWidgets('goes straight to the trip list after Kakao login', (
    tester,
  ) async {
    final server = fakeAuthServer();
    await pumpLogin(tester, server: server);

    await tester.tap(kakaoButton());
    await tester.pumpAndSettle();

    expect(sdk.calls, ['signIn kakao']);
    expect(server.requestsTo('/auth/login/kakao'), hasLength(1));
    expect(find.byType(TripListScreen), findsOneWidget);
  });

  testWidgets('goes straight to the trip list after Naver login', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(naverButton());
    await tester.pumpAndSettle();

    expect(sdk.calls, ['signIn naver']);
    expect(find.byType(TripListScreen), findsOneWidget);
  });

  testWidgets('shows nothing when the user cancels', (tester) async {
    sdk.onSignIn = (_) => null;
    await pumpLogin(tester);

    await tester.tap(kakaoButton());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  Future<void> expectMessage(
    WidgetTester tester,
    FakeHttp server,
    String message,
  ) async {
    await pumpLogin(tester, server: server);

    await tester.tap(naverButton());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  }

  testWidgets('asks to try later when the server answers 503', (tester) async {
    await expectMessage(
      tester,
      FakeHttp((_) => FakeReply.json(503)),
      testL10n.loginFailedUnavailable,
    );
  });

  testWidgets('asks to try again when the server answers 401', (tester) async {
    await expectMessage(
      tester,
      FakeHttp((_) => FakeReply.json(401)),
      testL10n.loginFailedRetry,
    );
  });

  testWidgets('asks to check the connection when the server is unreachable', (
    tester,
  ) async {
    await expectMessage(
      tester,
      FakeHttp((request) => throw connectionError(request)),
      testL10n.loginFailedNetwork,
    );
  });

  testWidgets('asks to try again when the SDK fails', (tester) async {
    sdk.onSignIn = (_) => throw const SocialSdkException('test');
    await pumpLogin(tester);

    await tester.tap(kakaoButton());
    await tester.pumpAndSettle();

    expect(find.text(testL10n.loginFailedRetry), findsOneWidget);
  });

  testWidgets('ignores taps while a login is in progress', (tester) async {
    final token = Completer<String?>();
    sdk.onSignIn = (_) => token.future;
    await pumpLogin(tester);

    await tester.tap(kakaoButton());
    await tester.pump();
    await tester.tap(naverButton());
    await tester.tap(kakaoButton());
    await tester.pump();

    expect(sdk.calls, ['signIn kakao']);
    token.complete(null);
    await tester.pumpAndSettle();
  });
}

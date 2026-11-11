import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/auth/account.dart';
import 'package:mapmarker_app/data/auth/auth_api.dart';
import 'package:mapmarker_app/data/auth/auth_session.dart';
import 'package:mapmarker_app/data/auth/social_sdk.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_http.dart';

Matcher _failsWith(LoginFailure failure) =>
    throwsA(isA<LoginException>().having((e) => e.failure, 'failure', failure));

void main() {
  late FakeHttp http;
  late FakeSocialSdk sdk;
  late AuthSession session;
  late Account account;

  void start({bool loggedIn = false}) {
    session = testSession(loggedIn: loggedIn, http: http);
    account = Account(session: session, api: AuthApi(fakeDio(http)), sdk: sdk);
    addTearDown(session.dispose);
  }

  setUp(() {
    http = fakeAuthServer(isNewUser: true);
    sdk = FakeSocialSdk();
  });

  group('logIn', () {
    test(
      'sends the Kakao id_token and signs in with the returned tokens',
      () async {
        start();

        final result = await account.logIn(SocialProvider.kakao);

        final request = http.requests.single;
        expect(request.uri.path, '/v1/auth/login/kakao');
        expect(request.data, {'idToken': 'provider-token'});
        expect(session.accessToken, testTokens.accessToken);
        expect(result?.isNewUser, isTrue);
      },
    );

    test('sends the Naver access token', () async {
      start();

      await account.logIn(SocialProvider.naver);

      final request = http.requests.single;
      expect(request.uri.path, '/v1/auth/login/naver');
      expect(request.data, {'accessToken': 'provider-token'});
      expect(session.isLoggedIn, isTrue);
    });

    test(
      'returns null and asks nothing of the server when the user cancels',
      () async {
        start();
        sdk.onSignIn = (_) => null;

        expect(await account.logIn(SocialProvider.kakao), isNull);
        expect(http.requests, isEmpty);
        expect(session.isLoggedIn, isFalse);
      },
    );

    test('fails as rejected when the SDK fails', () async {
      start();
      sdk.onSignIn = (_) => throw const SocialSdkException('test');

      await expectLater(
        account.logIn(SocialProvider.naver),
        _failsWith(LoginFailure.rejected),
      );
      expect(http.requests, isEmpty);
    });

    test('fails as network when the SDK cannot reach the provider', () async {
      start();
      sdk.onSignIn = (_) =>
          throw const SocialSdkException('test', network: true);

      await expectLater(
        account.logIn(SocialProvider.kakao),
        _failsWith(LoginFailure.network),
      );
    });

    Future<void> expectServerFailure(
      FakeHttp server,
      LoginFailure failure,
    ) async {
      http = server;
      start();

      await expectLater(
        account.logIn(SocialProvider.kakao),
        _failsWith(failure),
      );
      expect(session.isLoggedIn, isFalse);
    }

    test(
      'fails as rejected when the server refuses the provider token',
      () async {
        await expectServerFailure(
          FakeHttp((_) => FakeReply.json(401)),
          LoginFailure.rejected,
        );
      },
    );

    test(
      'fails as unavailable when the server cannot reach the provider',
      () async {
        await expectServerFailure(
          FakeHttp((_) => FakeReply.json(503)),
          LoginFailure.unavailable,
        );
      },
    );

    test('fails as network when the server is unreachable', () async {
      await expectServerFailure(
        FakeHttp((request) => throw connectionError(request)),
        LoginFailure.network,
      );
    });

    test('fails as rejected when the response has no tokens', () async {
      await expectServerFailure(
        FakeHttp((_) => const FakeReply.raw(200, '<html></html>')),
        LoginFailure.rejected,
      );
    });
  });

  group('logOut', () {
    test(
      'ends the session, tells the server, then signs out of the SDKs',
      () async {
        start(loggedIn: true);
        var loggedInAtSdkSignOut = true;
        var serverCallsAtSdkSignOut = 0;
        sdk.onSignOut = () {
          loggedInAtSdkSignOut = session.isLoggedIn;
          serverCallsAtSdkSignOut = http.requestsTo('/auth/logout').length;
        };

        await account.logOut();

        expect(session.isLoggedIn, isFalse);
        expect(http.requestsTo('/auth/logout').single.data, {
          'refreshToken': testTokens.refreshToken,
        });
        expect(sdk.calls, ['signOut']);
        expect(loggedInAtSdkSignOut, isFalse);
        expect(serverCallsAtSdkSignOut, 1);
      },
    );
  });
}

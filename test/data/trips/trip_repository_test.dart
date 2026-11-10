import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/data/auth/auth_session.dart';
import 'package:mapmarker_app/data/trips/memory_trip_repository.dart';
import 'package:mapmarker_app/data/trips/server_trip_repository.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/test_app.dart';

void main() {
  late AuthSession session;
  late ProviderContainer container;

  setUp(() {
    session = testSession();
    addTearDown(session.dispose);
    container = ProviderContainer.test(
      overrides: authOverrides(session: session),
    );
    // 화면 없이도 저장소를 붙잡아 둔다.
    container.listen(tripRepositoryProvider, (_, _) {});
  });

  test('uses the server when logged in', () {
    expect(container.read(tripRepositoryProvider), isA<ServerTripRepository>());
  });

  test('keeps nothing in memory while logged out', () async {
    await session.logOut();

    expect(container.read(tripRepositoryProvider), isA<MemoryTripRepository>());
  });

  test('makes a new repository for each login', () async {
    final first = container.read(tripRepositoryProvider);

    await session.logOut();
    await session.signIn(testTokens);
    final second = container.read(tripRepositoryProvider);

    // 앞 사용자의 여행을 기억한 저장소를 다음 사용자가 쓰지 않는다.
    expect(second, isA<ServerTripRepository>());
    expect(second, isNot(same(first)));
  });
}

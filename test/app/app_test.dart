import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/app.dart';
import 'package:mapmarker_app/app/missing_env_screen.dart';

void main() {
  testWidgets('shows setup guide naming every missing value', (tester) async {
    // 테스트는 --dart-define 없이 돌아서 모든 값이 비어 있다.
    await tester.pumpWidget(const ProviderScope(child: MapMarkerApp()));

    expect(find.byType(MissingEnvScreen), findsOneWidget);
    for (final name in [
      'NAVER_MAP_CLIENT_ID',
      'API_BASE_URL',
      'KAKAO_NATIVE_APP_KEY',
    ]) {
      expect(find.textContaining(name), findsOneWidget, reason: name);
    }
  });
}

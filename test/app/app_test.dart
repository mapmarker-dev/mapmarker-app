import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/app/app.dart';
import 'package:mapmarker_app/app/missing_env_screen.dart';

void main() {
  testWidgets('shows setup guide when NAVER_MAP_CLIENT_ID is missing', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MapMarkerApp()));

    expect(find.byType(MissingEnvScreen), findsOneWidget);
  });
}

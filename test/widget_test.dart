import 'package:flutter_test/flutter_test.dart';

import 'package:mapmarker_app/main.dart';

void main() {
  testWidgets('shows setup guide when NAVER_MAP_CLIENT_ID is missing', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MissingEnvScreen), findsOneWidget);
  });
}

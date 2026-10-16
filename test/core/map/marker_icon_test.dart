import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/map/map_provider.dart';
import 'package:mapmarker_app/core/map/marker_icon.dart';
import 'package:mapmarker_app/core/theme/app_theme.dart';

const _look = MarkerLook(
  fill: Colors.orange,
  foreground: Colors.black,
  halo: Colors.white,
);

Future<void> _pump(WidgetTester tester, MarkerLook look) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Center(child: MarkerIcon(look)),
  ),
);

void main() {
  testWidgets('draws a two-digit number with a badge in its size', (
    tester,
  ) async {
    await _pump(
      tester,
      const MarkerLook(
        fill: Colors.orange,
        foreground: Colors.black,
        halo: Colors.white,
        label: '12',
        badge: Icons.restaurant,
      ),
    );

    expect(tester.getSize(find.byType(MarkerIcon)), MarkerIcon.size);
    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draws an icon instead of a number', (tester) async {
    await _pump(
      tester,
      const MarkerLook(
        fill: Colors.indigo,
        foreground: Colors.white,
        halo: Colors.white,
        icon: Icons.bed,
      ),
    );

    expect(find.byIcon(Icons.bed), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  test('tells looks apart for the icon cache', () {
    expect(
      _look,
      const MarkerLook(
        fill: Colors.orange,
        foreground: Colors.black,
        halo: Colors.white,
      ),
    );
    expect(
      _look ==
          const MarkerLook(
            fill: Colors.orange,
            foreground: Colors.black,
            halo: Colors.white,
            label: '1',
          ),
      isFalse,
    );
  });
}

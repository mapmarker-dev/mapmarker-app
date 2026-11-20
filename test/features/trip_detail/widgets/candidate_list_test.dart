import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/candidate_list.dart';

import '../../../helpers/test_app.dart';

void main() {
  group('distanceText', () {
    String text(double meters) => distanceText(testL10n, meters);

    test('uses tens of meters under a kilometer', () {
      expect(text(0), '10m');
      expect(text(334), '330m');
      expect(text(994), '990m');
    });

    test('uses kilometers with one decimal under ten', () {
      expect(text(995), '1.0km');
      expect(text(1240), '1.2km');
      expect(text(9949), '9.9km');
    });

    test('rounds to whole kilometers from ten', () {
      expect(text(9950), '10km');
      expect(text(42300), '42km');
    });
  });

  test('mergeSortedBy keeps the original order for ties', () {
    expect(mergeSortedBy(['b', 'a', 'c', 'd'], (s) => s == 'c' ? 0 : 1), [
      'c',
      'b',
      'a',
      'd',
    ]);
  });
}

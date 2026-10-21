import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/features/trip_detail/widgets/route_day_sheet.dart';

void main() {
  group('sheetLiftAt', () {
    const minSize = 0.1;
    const height = 800.0;

    double? liftAt(double extent) =>
        sheetLiftAt(extent, minSize: minSize, height: height);

    test('is exactly zero near the folded height', () {
      // 접히는 애니메이션이 접힘 근처를 지날 때. 예전에는 1.2px이 남아 시트가 올라와 있다고 봤다.
      expect(liftAt(minSize + 0.0015), 0);
      expect(liftAt(minSize), 0);
      expect(liftAt(minSize - 0.001), 0);
    });

    test('uses the stop height, not the passing height', () {
      const mid = RouteDaySheet.midSize;
      const max = RouteDaySheet.maxSize;

      expect(liftAt(mid + 0.001), (mid - minSize) * height);
      expect(liftAt(max - 0.001), (max - minSize) * height);
    });

    test('is unknown between stop heights', () {
      expect(liftAt(0.25), isNull);
      expect(liftAt(0.55), isNull);
    });
  });
}

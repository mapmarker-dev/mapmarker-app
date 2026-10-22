import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapmarker_app/core/time/local_date.dart';
import 'package:mapmarker_app/core/time/today.dart';

void main() {
  testWidgets('reads today again when the app comes back', (tester) async {
    var now = DateTime(2026, 10, 15, 23, 50);
    final container = ProviderContainer.test(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    expect(container.read(todayProvider), LocalDate(2026, 10, 15));

    // 자정을 넘겨 백그라운드에 있다가 다시 앞으로 나온다.
    now = DateTime(2026, 10, 16, 0, 10);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(container.read(todayProvider), LocalDate(2026, 10, 16));
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_date.dart';

/// 지금 시각. 테스트에서 덮어써서 시각을 고정한다.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 오늘 날짜. 기기 시간대 기준이다.
///
/// 해외에 가면 휴대폰 시간대가 현지로 바뀌므로 자연스럽게 현지 날짜가 된다.
/// 자정을 넘겨 켜 둔 경우를 위해 앱이 다시 앞으로 나올 때 다시 읽는다.
final todayProvider = NotifierProvider<TodayNotifier, LocalDate>(
  TodayNotifier.new,
);

class TodayNotifier extends Notifier<LocalDate> {
  @override
  LocalDate build() {
    final clock = ref.watch(clockProvider);
    final listener = AppLifecycleListener(
      onResume: () {
        final today = LocalDate.fromDateTime(clock());
        if (today != state) state = today;
      },
    );
    ref.onDispose(listener.dispose);
    return LocalDate.fromDateTime(clock());
  }
}

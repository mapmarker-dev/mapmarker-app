import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/trip.dart';
import '../../data/models/trip_route.dart';
import '../../data/trips/trip_repository.dart';
import '../../l10n/l10n.dart';

/// 여행 화면에 보여 줄 여행. 없는 여행이면 null이다.
final tripDetailProvider = StreamNotifierProvider.autoDispose
    .family<TripDetailController, Trip?, String>(TripDetailController.new);

class TripDetailController extends StreamNotifier<Trip?> {
  TripDetailController(this.tripId);

  final String tripId;

  @override
  Stream<Trip?> build() => ref.watch(tripRepositoryProvider).watchTrip(tripId);

  /// 비우면 기본 제목으로 되돌린다.
  Future<void> rename(String title) async {
    final trip = state.value;
    if (trip == null) return;
    final trimmed = title.trim();
    final defaultTitle = ref.read(l10nProvider).defaultTitleOf(trip);
    await ref
        .read(tripRepositoryProvider)
        .updateTrip(
          trip.copyWith(title: trimmed.isEmpty ? defaultTitle : trimmed),
        );
  }
}

/// 여행의 장소와 구간.
final tripRouteProvider = StreamProvider.autoDispose.family<TripRoute, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).watchRoute(tripId),
);

/// 동선 페이지에서 고른 보기. 화면 상태라서 저장하지 않고, 페이지를 나가면 처음으로 돌아간다.
@immutable
class RouteChoice {
  const RouteChoice({this.day, this.showLodging = true, this.fitCount = 0});

  /// 보는 일차. null이면 여행 전체다.
  final int? day;

  final bool showLodging;

  /// 카메라를 맞추라고 한 횟수. 바뀔 때마다 지도가 보이는 장소에 카메라를 맞춘다.
  /// 장소가 바뀌어도 이 값이 같으면 카메라는 그대로다.
  final int fitCount;
}

final routeChoiceProvider = NotifierProvider.autoDispose
    .family<RouteChoiceController, RouteChoice, String>(
      RouteChoiceController.new,
    );

class RouteChoiceController extends Notifier<RouteChoice> {
  RouteChoiceController(this.tripId);

  final String tripId;

  @override
  RouteChoice build() => const RouteChoice();

  /// 일차를 고른다. null이면 여행 전체다. 지금 보는 일차를 다시 골라도 카메라를 다시 맞춘다.
  void selectDay(int? day) => state = RouteChoice(
    day: day,
    showLodging: state.showLodging,
    fitCount: state.fitCount + 1,
  );

  void setShowLodging(bool show) => state = RouteChoice(
    day: state.day,
    showLodging: show,
    fitCount: state.fitCount + 1,
  );

  void fitCamera() => state = RouteChoice(
    day: state.day,
    showLodging: state.showLodging,
    fitCount: state.fitCount + 1,
  );
}

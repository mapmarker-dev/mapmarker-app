import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/stop.dart';
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

  /// [Stop.day]일차의 [Stop.order] 자리에 넣는다. 앞뒤 장소와의 구간은 저장소가 만든다.
  Future<Stop> addStop(Stop stop) =>
      ref.read(tripRepositoryProvider).addStop(stop);

  /// 이름·종류·설명·메모·예정 시각을 바꾼다. 일차는 [moveStop]으로 옮긴다.
  Future<Stop> updateStop(Stop stop) =>
      ref.read(tripRepositoryProvider).updateStop(stop);

  /// 앞뒤 장소는 저장소가 새 구간으로 잇는다.
  Future<void> deleteStop(String stopId) =>
      ref.read(tripRepositoryProvider).deleteStop(stopId);

  /// 장소를 [day]일차의 [order] 자리로 옮긴다. 이웃이 바뀐 구간의 이동 수단은 저장소가 지운다.
  Future<void> moveStop(
    String stopId, {
    required int day,
    required int order,
  }) =>
      ref.read(tripRepositoryProvider).moveStop(stopId, day: day, order: order);
}

/// 여행의 장소와 구간.
final tripRouteProvider = StreamProvider.autoDispose.family<TripRoute, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).watchRoute(tripId),
);

/// 동선 페이지에서 고른 보기. 화면 상태라서 저장하지 않고, 페이지를 나가면 처음으로 돌아간다.
@immutable
class RouteChoice {
  const RouteChoice({
    this.day,
    this.showLodging = true,
    this.fitCount = 0,
    this.focus = const [],
    this.focusCount = 0,
  });

  /// 보는 일차. null이면 여행 전체다.
  final int? day;

  final bool showLodging;

  /// 카메라를 맞추라고 한 횟수. 바뀔 때마다 지도가 보이는 장소에 카메라를 맞춘다.
  /// 장소가 바뀌어도 이 값이 같으면 카메라는 그대로다.
  final int fitCount;

  /// 일차 동선 시트에서 보여 줄 장소나 구간의 ID. 지도에서 누른 것이다.
  /// 같은 자리의 마커를 누르면 그 자리의 장소가 모두 들어 있다.
  final List<String> focus;

  /// [focus]를 보여 달라고 한 횟수. 바뀔 때마다 시트를 펼쳐 [focus]로 넘긴다.
  /// 같은 마커를 다시 눌러도 다시 보여 주려고 센다.
  final int focusCount;

  RouteChoice _copyWith({
    int? Function()? day,
    bool? showLodging,
    int? fitCount,
    List<String>? focus,
    int? focusCount,
  }) => RouteChoice(
    day: day == null ? this.day : day(),
    showLodging: showLodging ?? this.showLodging,
    fitCount: fitCount ?? this.fitCount,
    focus: focus ?? this.focus,
    focusCount: focusCount ?? this.focusCount,
  );
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
  /// [focus]를 주면 시트에서 그 장소나 구간을 보여 준다(지도에서 눌러 일차로 들어올 때).
  void selectDay(int? day, {List<String> focus = const []}) =>
      state = state._copyWith(
        day: () => day,
        fitCount: state.fitCount + 1,
        focus: focus,
        focusCount: focus.isEmpty ? null : state.focusCount + 1,
      );

  /// 지금 일차의 시트에서 [ids] 장소나 구간을 보여 준다. 카메라는 그대로다.
  void focusOn(List<String> ids) =>
      state = state._copyWith(focus: ids, focusCount: state.focusCount + 1);

  void setShowLodging(bool show) => state = state._copyWith(
    showLodging: show,
    fitCount: state.fitCount + 1,
    focus: const [],
  );

  void fitCamera() => state = state._copyWith(fitCount: state.fitCount + 1);
}

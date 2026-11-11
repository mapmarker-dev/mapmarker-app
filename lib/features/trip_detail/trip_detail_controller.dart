import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/segment.dart';
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

  /// 이동 수단을 바꾼다. 비우면 미정이다.
  Future<Segment> updateSegment(Segment segment) =>
      ref.read(tripRepositoryProvider).updateSegment(segment);
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
    this.candidateView = false,
    this.showLodging = true,
    this.showCandidates = true,
    this.fitCount = 0,
    this.focus = const [],
    this.focusCount = 0,
    this.panelOpen = true,
  }) : assert(day == null || !candidateView);

  /// 보는 일차. null이면 여행 전체이거나 "후보" 보기다.
  final int? day;

  /// "후보" 보기(일차 칩 줄 끝의 "후보" 칩). 지도는 동선 전체를 흐리게 깔고 후보를 올리며, 시트·패널에 후보 목록이 나온다.
  final bool candidateView;

  final bool showLodging;

  /// "후보 보기" 칩. 켜면 전체·일차 보기에도 후보가 보인다. "후보" 보기에서는 이것과 상관없이 보인다.
  /// 처음에는 켜져 있다. 꺼져 있을 때 후보가 생겨도 앱이 몰래 켜지 않는다(스낵바로 알린다).
  final bool showCandidates;

  /// 아래 시트나 오른쪽 패널에 목록(일차 동선이나 후보)이 있는 보기인지.
  bool get hasList => day != null || candidateView;

  /// 카메라를 맞추라고 한 횟수. 바뀔 때마다 지도가 보이는 장소에 카메라를 맞춘다.
  /// 장소가 바뀌어도 이 값이 같으면 카메라는 그대로다.
  final int fitCount;

  /// 일차 동선 시트에서 보여 줄 장소나 구간의 ID. 지도에서 누른 것이다.
  /// 같은 자리의 마커를 누르면 그 자리의 장소가 모두 들어 있다.
  final List<String> focus;

  /// [focus]를 보여 달라고 한 횟수. 바뀔 때마다 시트를 펼쳐 [focus]로 넘긴다.
  /// 같은 마커를 다시 눌러도 다시 보여 주려고 센다.
  final int focusCount;

  /// 가로이고 넓은 화면의 오른쪽 패널이 열려 있는지. 아래 시트에는 쓰지 않는다(시트는 끌어서 높이를 정한다).
  /// 기기를 돌려도 남게 화면 상태로 둔다.
  final bool panelOpen;

  RouteChoice _copyWith({
    int? Function()? day,
    bool? candidateView,
    bool? showLodging,
    bool? showCandidates,
    int? fitCount,
    List<String>? focus,
    int? focusCount,
    bool? panelOpen,
  }) => RouteChoice(
    day: day == null ? this.day : day(),
    candidateView: candidateView ?? this.candidateView,
    showLodging: showLodging ?? this.showLodging,
    showCandidates: showCandidates ?? this.showCandidates,
    fitCount: fitCount ?? this.fitCount,
    focus: focus ?? this.focus,
    focusCount: focusCount ?? this.focusCount,
    panelOpen: panelOpen ?? this.panelOpen,
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
  /// 일차를 고르면 오른쪽 패널이 열린다.
  void selectDay(int? day, {List<String> focus = const []}) =>
      state = state._copyWith(
        day: () => day,
        candidateView: false,
        fitCount: state.fitCount + 1,
        focus: focus,
        focusCount: focus.isEmpty ? null : state.focusCount + 1,
        panelOpen: true,
      );

  /// "후보" 보기로 간다. 카메라는 후보에 맞춘다. [focus]를 주면 목록에서 그 후보를 펼친다(지도에서 후보를 눌렀을 때).
  /// 오른쪽 패널이 열린다.
  void selectCandidates({List<String> focus = const []}) =>
      state = state._copyWith(
        day: () => null,
        candidateView: true,
        fitCount: state.fitCount + 1,
        focus: focus,
        focusCount: focus.isEmpty ? null : state.focusCount + 1,
        panelOpen: true,
      );

  /// 카메라는 그대로다. 카메라 맞춤은 후보를 넣지 않아서다.
  void setShowCandidates(bool show) =>
      state = state._copyWith(showCandidates: show, focus: const []);

  /// 지금 일차의 시트에서 [ids] 장소나 구간을 보여 준다. 카메라는 그대로다. 닫힌 패널은 연다.
  void focusOn(List<String> ids) => state = state._copyWith(
    focus: ids,
    focusCount: state.focusCount + 1,
    panelOpen: true,
  );

  /// 오른쪽 패널을 닫는다. 일차를 고르거나 지도에서 장소·선을 누르면 다시 열린다.
  void closePanel() => state = state._copyWith(panelOpen: false);

  void setShowLodging(bool show) => state = state._copyWith(
    showLodging: show,
    fitCount: state.fitCount + 1,
    focus: const [],
  );

  void fitCamera() => state = state._copyWith(fitCount: state.fitCount + 1);
}

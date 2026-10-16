import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/trip.dart';
import '../../data/trips/trip_repository.dart';

/// 여행 목록. 최근에 만들거나 고친 여행이 앞에 온다.
final tripListProvider = StreamNotifierProvider<TripListController, List<Trip>>(
  TripListController.new,
);

class TripListController extends StreamNotifier<List<Trip>> {
  @override
  Stream<List<Trip>> build() => ref.watch(tripRepositoryProvider).watchTrips();

  /// 상태를 직접 정한다. [phase]가 null이면 자동으로 되돌린다.
  Future<void> setPhase(Trip trip, TripPhase? phase) async {
    if (trip.phaseOverride == phase) return;
    await ref
        .read(tripRepositoryProvider)
        .updateTrip(trip.copyWith(phaseOverride: () => phase));
  }
}

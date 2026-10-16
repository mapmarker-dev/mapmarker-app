import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/trip.dart';
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

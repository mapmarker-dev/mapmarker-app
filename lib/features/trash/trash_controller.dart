import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/trashed_trip.dart';
import '../../data/models/trip.dart';
import '../../data/trips/trip_repository.dart';

/// 휴지통. 화면을 열 때마다 서버에서 받는다(저장소가 기억하지 않는다). 최근에 넣은 여행이 앞에 온다.
final trashProvider =
    AsyncNotifierProvider.autoDispose<TrashController, List<TrashedTrip>>(
      TrashController.new,
    );

class TrashController extends AsyncNotifier<List<TrashedTrip>> {
  @override
  Future<List<TrashedTrip>> build() =>
      ref.watch(tripRepositoryProvider).fetchTrash();

  /// 다시 받는다(당겨서 새로고침). 실패하면 던지고, 보이던 목록은 그대로 둔다.
  Future<void> refresh() async {
    final trash = await ref.read(tripRepositoryProvider).fetchTrash();
    if (ref.mounted) state = AsyncData(trash);
  }

  /// 되살리고 휴지통에서 뺀다. 여행 목록에는 저장소가 다시 넣는다.
  /// 휴지통에 이미 없으면(보관 기간이 끝났거나 다른 기기에서 지웠다) 휴지통을 다시 받은 뒤 던진다.
  Future<Trip> restore(String tripId) async {
    try {
      final trip = await ref.read(tripRepositoryProvider).restoreTrip(tripId);
      _drop(tripId);
      return trip;
    } on ApiException catch (error) {
      if (error.failure == ApiFailure.notFound) await _reloadQuietly();
      rethrow;
    }
  }

  /// 영구 삭제하고 휴지통에서 뺀다. 이미 없으면 저장소가 지운 것으로 본다.
  Future<void> deleteForever(String tripId) async {
    await ref.read(tripRepositoryProvider).deleteTripForever(tripId);
    _drop(tripId);
  }

  void _drop(String tripId) {
    final trash = state.value;
    if (!ref.mounted || trash == null) return;
    state = AsyncData([
      for (final item in trash)
        if (item.trip.id != tripId) item,
    ]);
  }

  Future<void> _reloadQuietly() async {
    try {
      await refresh();
    } on ApiException {
      // 되살리기 실패 안내가 먼저다. 목록은 다음에 당겨서 새로고침한다.
    }
  }
}

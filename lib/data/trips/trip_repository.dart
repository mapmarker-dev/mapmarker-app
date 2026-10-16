import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/today.dart';
import '../models/trip.dart';
import 'memory_trip_repository.dart';

/// 여행 저장소. 서버가 생기기 전에는 메모리 구현을 쓰고, 서버 API를 붙일 때 구현만 바꾼다.
///
/// 화면은 `watch`로 받은 값을 보여 주고, 저장소가 바뀌면 새 값을 받아 다시 그린다.
/// 서버 구현도 받아 온 여행을 기억해 두고, 이 앱에서 바꾼 내용을 반영해 다시 내보낸다.
abstract interface class TripRepository {
  /// 내 여행 목록. 최근에 만들거나 고친 여행이 앞에 온다.
  Stream<List<Trip>> watchTrips();

  /// 여행 하나. 없으면 null을 낸다.
  Stream<Trip?> watchTrip(String id);

  /// 저장한 여행을 돌려준다. 만든 시각과 고친 시각은 저장소가 정한다.
  Future<Trip> createTrip(Trip trip);

  /// 저장한 여행을 돌려준다. 없는 여행이면 [StateError]를 던진다.
  Future<Trip> updateTrip(Trip trip);
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final repository = MemoryTripRepository(clock: ref.watch(clockProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

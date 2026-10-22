import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/today.dart';
import '../models/segment.dart';
import '../models/stop.dart';
import '../models/trip.dart';
import '../models/trip_route.dart';
import 'memory_trip_repository.dart';

/// 여행 저장소. 서버가 생기기 전에는 메모리 구현을 쓰고, 서버 API를 붙일 때 구현만 바꾼다.
///
/// 화면은 `watch`로 받은 값을 보여 주고, 저장소가 바뀌면 새 값을 받아 다시 그린다.
/// 서버 구현도 받아 온 여행을 기억해 두고, 이 앱에서 바꾼 내용을 반영해 다시 내보낸다.
///
/// 장소 순서는 일차마다 0부터 빈칸 없이 저장소가 다시 매긴다.
/// 구간은 이웃한 장소 사이에 저장소가 만들고 지운다(`route_links.dart`).
/// 장소나 구간을 바꾸면 여행의 고친 시각도 바뀐다. 여행 목록이 최근에 고친 순서라서다.
abstract interface class TripRepository {
  /// 내 여행 목록. 최근에 만들거나 고친 여행이 앞에 온다.
  Stream<List<Trip>> watchTrips();

  /// 여행 하나. 없으면 null을 낸다.
  Stream<Trip?> watchTrip(String id);

  /// 저장한 여행을 돌려준다. 만든 시각과 고친 시각은 저장소가 정한다.
  Future<Trip> createTrip(Trip trip);

  /// 저장한 여행을 돌려준다. 없는 여행이면 [StateError]를 던진다.
  Future<Trip> updateTrip(Trip trip);

  /// 여행의 장소와 구간. 장소와 구간을 한 값으로 내서, 둘이 어긋난 중간 상태가 보이지 않는다.
  /// 없는 여행이면 빈 동선을 낸다.
  Stream<TripRoute> watchRoute(String tripId);

  /// 장소를 그 일차의 [Stop.order] 자리에 끼워 넣고, 뒤 장소를 하나씩 민다.
  /// 그 일차의 장소 수보다 크면 맨 뒤에 넣는다.
  ///
  /// 없는 여행이거나 이미 있는 장소면 [StateError],
  /// 일차가 1부터 여행 일수(박 + 1) 밖이면 [RangeError]를 던진다.
  Future<Stop> addStop(Stop stop);

  /// 이름·좌표·종류·설명·메모 등을 바꾼다. 일차와 순서는 [moveStop]으로 바꾼다.
  Future<Stop> updateStop(Stop stop);

  /// 장소를 [day]일차의 [order] 자리로 옮긴다. [order]가 크면 맨 뒤로 간다.
  Future<Stop> moveStop(String stopId, {required int day, required int order});

  /// 장소를 지운다. 앞뒤 장소는 새 구간으로 이어진다.
  Future<void> deleteStop(String stopId);

  /// 이동 수단·곡률·종류만 바꾼다. 어느 장소를 잇는지는 저장소가 정한다.
  Future<Segment> updateSegment(Segment segment);
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final repository = MemoryTripRepository(clock: ref.watch(clockProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

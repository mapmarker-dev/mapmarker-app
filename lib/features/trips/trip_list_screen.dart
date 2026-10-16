import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/time/today.dart';
import 'trip_list_controller.dart';
import 'widgets/trip_tile.dart';

/// 여행 목록. 로그인 후 첫 화면이다.
class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MapMarker'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: '스냅샷 검증',
              icon: const Icon(Icons.science_outlined),
              onPressed: () => context.go(Routes.snapshotLab),
            ),
        ],
      ),
      body: switch (ref.watch(tripListProvider)) {
        AsyncData(value: final trips) when trips.isEmpty => const Center(
          child: Text(
            '아직 여행이 없습니다.\n+ 버튼으로 첫 여행을 만들어 보세요.',
            textAlign: TextAlign.center,
          ),
        ),
        AsyncData(value: final trips) => ListView.builder(
          // 마지막 여행이 + 버튼에 가리지 않게 한다.
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            return TripTile(
              trip: trip,
              today: today,
              onTap: () => context.go(Routes.trip(trip.id)),
              onPhaseChanged: (phase) =>
                  ref.read(tripListProvider.notifier).setPhase(trip, phase),
            );
          },
        ),
        AsyncError() => const Center(child: Text('여행 목록을 불러오지 못했습니다.')),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        tooltip: '여행 만들기',
        onPressed: () => context.go(Routes.tripCreate),
        child: const Icon(Icons.add),
      ),
    );
  }
}

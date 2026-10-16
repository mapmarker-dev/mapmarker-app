import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/time/today.dart';
import '../../l10n/l10n.dart';
import 'trip_list_controller.dart';
import 'widgets/trip_tile.dart';

/// 여행 목록. 로그인 후 첫 화면이다.
class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final l10n = context.l10n;
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
        AsyncData(value: final trips) when trips.isEmpty => Center(
          child: Text(l10n.tripListEmpty, textAlign: TextAlign.center),
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
        AsyncError() => Center(child: Text(l10n.tripListLoadFailed)),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.createTripTooltip,
        onPressed: () => context.go(Routes.tripCreate),
        child: const Icon(Icons.add),
      ),
    );
  }
}

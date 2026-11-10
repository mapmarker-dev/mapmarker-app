import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/local_date.dart';
import '../../core/time/today.dart';
import '../../data/api/api_exception.dart';
import '../../data/auth/account.dart';
import '../../data/models/trip.dart';
import '../../data/sample/jeju_sample.dart';
import '../../data/trips/trip_repository.dart';
import '../../l10n/l10n.dart';
import 'trip_list_controller.dart';
import 'widgets/delete_trip_dialog.dart';
import 'widgets/trip_card.dart';

/// 한 줄에 놓는 여행 카드 수. 휴대폰은 2개, 태블릿은 폭에 따라 3~4개다.
int tripGridColumns(double width) => switch (width) {
  >= 900 => 4,
  >= 600 => 3,
  _ => 2,
};

/// 앱 바 ⋮ 메뉴의 항목.
enum _Menu { logOut }

/// 당겨서 서버에서 다시 받는다. 실패하면 알리고 보이던 목록은 그대로 둔다.
class _PullToRefresh extends ConsumerWidget {
  const _PullToRefresh({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: () async {
      try {
        await ref.read(tripRepositoryProvider).refreshTrips();
      } on ApiException {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.refreshFailed)));
      }
    },
    child: child,
  );
}

/// 앱으로 돌아오면 지금 보는 목록과 여행을 뒤에서 다시 받는다. 다른 기기에서 바꾼 것을 보여 주려고서다.
/// 여행 목록은 로그인한 동안 늘 경로 표 맨 아래에 있어서 여기에 둔다.
class _RefreshOnResume extends ConsumerStatefulWidget {
  const _RefreshOnResume({required this.child});

  final Widget child;

  @override
  ConsumerState<_RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends ConsumerState<_RefreshOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () => ref.read(tripRepositoryProvider).refreshWatched(),
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 여행 목록. 로그인 후 첫 화면이다. 여행이 정사각형 카드로 놓인다.
class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  /// 마지막 줄이 + 버튼(56)에 가리지 않게 남기는 아래 여백.
  static const _fabClearance = 56 + AppSpace.lg * 2;

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
          // 설정 화면(1-6단계)이 생기면 그리로 옮긴다.
          PopupMenuButton<_Menu>(
            tooltip: l10n.moreMenuTooltip,
            onSelected: (item) => switch (item) {
              _Menu.logOut => _confirmLogOut(context, ref),
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: _Menu.logOut, child: Text(l10n.logOut)),
            ],
          ),
        ],
      ),
      body: _RefreshOnResume(
        child: switch (ref.watch(tripListProvider)) {
          AsyncData(value: final trips) when trips.isEmpty => _PullToRefresh(
            child: LayoutBuilder(
              // 빈 목록도 당길 수 있게 화면 높이만큼 스크롤 영역을 둔다.
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Center(
                    child: Text(
                      l10n.tripListEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          AsyncData(value: final trips) => _PullToRefresh(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _grid(context, ref, trips, today, constraints),
            ),
          ),
          AsyncValue(isLoading: true) => const Center(
            child: CircularProgressIndicator(),
          ),
          AsyncError() => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.tripListLoadFailed, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.md),
                FilledButton.tonal(
                  // 목록을 새로 들으면 저장소가 서버에서 다시 받는다.
                  onPressed: () => ref.invalidate(tripListProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.createTripTooltip,
        onPressed: () => context.go(Routes.tripCreate),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    WidgetRef ref,
    List<Trip> trips,
    LocalDate today,
    BoxConstraints constraints,
  ) => GridView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    // 시스템 막대만큼 더 띄운다. 카드는 막대 뒤로 지나가도 끝까지 보인다.
    padding:
        const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          _fabClearance,
        ) +
        MediaQuery.paddingOf(context),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: tripGridColumns(constraints.maxWidth),
      mainAxisSpacing: AppSpace.md,
      crossAxisSpacing: AppSpace.md,
    ),
    itemCount: trips.length,
    itemBuilder: (context, index) {
      final trip = trips[index];
      return TripCard(
        trip: trip,
        today: today,
        onTap: () => context.go(Routes.trip(trip.id)),
        onPhaseChanged: (phase) => _setPhase(context, ref, trip, phase),
        onDelete: () => _confirmDelete(context, ref, trip),
      );
    },
  );

  Future<void> _setPhase(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
    TripPhase? phase,
  ) async {
    try {
      await ref.read(tripListProvider.notifier).setPhase(trip, phase);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.saveFailureText(error.failure))),
      );
    }
  }

  /// 확인을 받아 여행을 휴지통으로 옮긴다. 옮길 때까지 확인 창이 열려 있고, 실패는 그 안에서 알린다.
  /// 샘플은 이 기기에서 숨긴다.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Trip trip) {
    final repository = ref.read(tripRepositoryProvider);
    final sample = isSampleTrip(trip.id);
    return showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return DeleteTripDialog(
          title: sample ? l10n.deleteSampleTitle : l10n.deleteTripTitle,
          message: sample
              ? l10n.deleteSampleMessage
              : l10n.deleteTripMessage(trip.title),
          onDelete: () => repository.trashTrip(trip.id),
        );
      },
    );
  }

  /// 확인을 받아 로그아웃한다. 로그아웃하면 경로 표가 로그인 화면으로 보낸다.
  Future<void> _confirmLogOut(BuildContext context, WidgetRef ref) async {
    final account = ref.read(accountProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.logOutConfirmTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.logOut),
            ),
          ],
        );
      },
    );
    if (confirmed == true) await account.logOut();
  }
}

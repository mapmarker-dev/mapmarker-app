import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/today.dart';
import '../../data/auth/account.dart';
import '../../l10n/l10n.dart';
import 'trip_list_controller.dart';
import 'widgets/trip_card.dart';

/// 한 줄에 놓는 여행 카드 수. 휴대폰은 2개, 태블릿은 폭에 따라 3~4개다.
int tripGridColumns(double width) => switch (width) {
  >= 900 => 4,
  >= 600 => 3,
  _ => 2,
};

/// 앱 바 ⋮ 메뉴의 항목.
enum _Menu { logOut }

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
      body: switch (ref.watch(tripListProvider)) {
        AsyncData(value: final trips) when trips.isEmpty => Center(
          child: Text(l10n.tripListEmpty, textAlign: TextAlign.center),
        ),
        AsyncData(value: final trips) => LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
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
                onPhaseChanged: (phase) =>
                    ref.read(tripListProvider.notifier).setPhase(trip, phase),
              );
            },
          ),
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

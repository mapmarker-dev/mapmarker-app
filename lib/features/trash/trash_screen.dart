import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/time/today.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../core/widgets/saving.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/trashed_trip.dart';
import '../../l10n/l10n.dart';
import 'trash_controller.dart';

/// 완전히 지워질 때까지 남은 날. 하루 단위로 올림하고, 하루가 안 남았으면 0이다.
/// 방금 넣은 여행이 "30일 뒤"로 보이게 올림한다.
int trashDaysLeft(DateTime purgeAt, DateTime now) {
  final left = purgeAt.difference(now);
  if (left < const Duration(days: 1)) return 0;
  return (left.inMicroseconds / Duration.microsecondsPerDay).ceil();
}

/// 줄의 ⋮ 메뉴 항목.
enum _Action { restore, deleteForever }

/// 휴지통. 지운 여행을 되살리거나 영구 삭제한다. 여행 목록 ⋮ 메뉴에서 연다.
/// 휴지통의 여행은 열어 보지 않는다(되살리면 볼 수 있다).
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  /// 되살리는 중인 여행. 그 줄에 진행 표시를 띄우고 메뉴를 잠근다.
  final _restoring = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trash)),
      body: switch (ref.watch(trashProvider)) {
        AsyncData(value: final trash) when trash.isEmpty => _pullToRefresh(
          LayoutBuilder(
            // 빈 휴지통도 당길 수 있게 화면 높이만큼 스크롤 영역을 둔다.
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Text(l10n.trashEmpty, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
        AsyncData(value: final trash) => _pullToRefresh(_list(trash)),
        AsyncError() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.trashLoadFailed, textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.md),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(trashProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// 당겨서 다시 받는다. 실패하면 알리고 보이던 목록은 그대로 둔다.
  Widget _pullToRefresh(Widget child) => RefreshIndicator(
    onRefresh: () async {
      try {
        await ref.read(trashProvider.notifier).refresh();
      } on ApiException {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.refreshFailed)));
      }
    },
    child: child,
  );

  Widget _list(List<TrashedTrip> trash) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider)();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      // 시스템 막대만큼 더 띄운다. 줄은 막대 뒤로 지나가도 끝까지 보인다.
      padding:
          const EdgeInsets.symmetric(vertical: AppSpace.sm) +
          MediaQuery.paddingOf(context),
      itemCount: trash.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = trash[index];
        final trip = item.trip;
        final days = trashDaysLeft(item.purgeAt, now);
        return ListTile(
          title: Text(trip.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            l10n.trashItemSummary(
              trip.region,
              days == 0
                  ? l10n.trashPurgeWithinDay
                  : l10n.trashPurgeInDays(days),
            ),
          ),
          trailing: _restoring.contains(trip.id)
              ? SavingIndicator(label: l10n.saving)
              : PopupMenuButton<_Action>(
                  tooltip: l10n.trashItemMenuTooltip,
                  onSelected: (action) => switch (action) {
                    _Action.restore => _restore(item),
                    _Action.deleteForever => _confirmDeleteForever(item),
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _Action.restore,
                      child: Text(l10n.restoreTrip),
                    ),
                    PopupMenuItem(
                      value: _Action.deleteForever,
                      child: Text(l10n.deleteTripForever),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// 한 번 누르는 저장이라 그 줄에 진행 표시를 띄우고, 결과는 스낵바로 알린다.
  Future<void> _restore(TrashedTrip item) async {
    final id = item.trip.id;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _restoring.add(id));
    try {
      await ref.read(trashProvider.notifier).restore(id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tripRestored(item.trip.title))),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.failure == ApiFailure.notFound
                ? l10n.restoreGone
                : l10n.saveFailureText(error.failure),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoring.remove(id));
    }
  }

  /// 확인을 받아 영구 삭제한다. 지울 때까지 확인 창이 열려 있고, 실패는 그 안에서 알린다.
  Future<void> _confirmDeleteForever(TrashedTrip item) {
    final controller = ref.read(trashProvider.notifier);
    return showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return ConfirmDeleteDialog(
          title: l10n.deleteForeverTitle,
          message: l10n.deleteForeverMessage(item.trip.title),
          confirmLabel: l10n.deleteTripForever,
          onConfirm: () => controller.deleteForever(item.trip.id),
        );
      },
    );
  }
}

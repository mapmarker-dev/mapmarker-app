import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/candidate.dart';
import '../../../data/models/trip_route.dart';
import '../../../l10n/l10n.dart';
import '../route_scene.dart';
import 'day_itinerary_list.dart';
import 'itinerary_tiles.dart';

/// "후보 목록" 보기의 후보 목록. 넣은 순서다. 아래 시트와 오른쪽 패널이 함께 쓴다.
///
/// 줄을 누르면 고르고 펼친다(일차 동선 목록과 같은 [ItinerarySelection]을 쓴다).
/// 지도에서 누른 후보([focus])는 [onReveal]로 틀을 연 뒤 그 줄로 넘기고 펼친다.
class CandidateList extends StatefulWidget {
  const CandidateList({
    super.key,
    required this.route,
    required this.selection,
    required this.focus,
    required this.focusCount,
    required this.onReveal,
    required this.onOpenMap,
    this.onEdit,
    this.onPromote,
    this.padding = EdgeInsets.zero,
  });

  final TripRoute route;
  final ItinerarySelection selection;

  /// 지도에서 눌러서 보여 줄 후보. [focusCount]가 바뀔 때 보여 준다.
  final List<String> focus;
  final int focusCount;

  /// 지도에서 누른 줄로 넘기기 전에 목록이 보이게 틀을 연다.
  final Future<void> Function() onReveal;

  final ValueChanged<Candidate> onOpenMap;

  /// 후보 줄의 연필 아이콘을 눌렀다(후보 입력 화면을 연다). 연필은 목록에서 누른 줄에만 보인다.
  /// null이면 연필이 없다(보기만 하는 샘플).
  final ValueChanged<Candidate>? onEdit;

  /// 펼친 후보 줄의 [동선에 넣기]를 눌렀다(후보 값으로 채운 장소 입력 화면을 연다).
  /// 지도에서 눌러 펼친 줄에도 있다. 보고 바로 넣기로 정할 수 있어서다. null이면 없다(보기만 하는 샘플).
  final ValueChanged<Candidate>? onPromote;

  /// 목록 바깥 여백. 아래 시트는 시스템 여백을 더한다.
  final EdgeInsets padding;

  @override
  State<CandidateList> createState() => _CandidateListState();
}

class _CandidateListState extends State<CandidateList> {
  final _keys = <String, GlobalKey>{};

  /// 보여 주려고 예약한 지도 탭. 한 프레임에 여러 번 다시 그려져도 한 번만 보여 준다.
  int? _scheduledFocusCount;

  static const _moveDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_onSelection);
    _showFocusIfNew();
  }

  @override
  void didUpdateWidget(CandidateList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection.removeListener(_onSelection);
      widget.selection.addListener(_onSelection);
    }
    _showFocusIfNew();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelection);
    super.dispose();
  }

  void _onSelection() => setState(() {});

  /// 지도에서 새로 누른 후보가 있으면 고르고 펼친 뒤, 틀을 열고 그 줄로 넘긴다.
  void _showFocusIfNew() {
    final focus = widget.focus;
    final selection = widget.selection;
    final count = widget.focusCount;
    if (focus.isEmpty ||
        count == selection.shownFocusCount ||
        count == _scheduledFocusCount) {
      return;
    }
    _scheduledFocusCount = count;
    // initState·didUpdateWidget에서 불러서, 알림은 그리기가 끝난 뒤에 보낸다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.focusCount != count) return;
      selection.focus(
        focus,
        stopId: focus
            .where((id) => widget.route.candidateById(id) != null)
            .firstOrNull,
        count: count,
      );
      await widget.onReveal();
      if (!mounted) return;
      final target = focus
          .map((id) => _keys[id]?.currentContext)
          .nonNulls
          .firstOrNull;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target, duration: _moveDuration);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selection = widget.selection;
    final candidates = widget.route.candidates;
    final onEdit = widget.onEdit;
    final onPromote = widget.onPromote;
    final side = EdgeInsets.only(
      left: widget.padding.left + AppSpace.sm,
      right: widget.padding.right + AppSpace.sm,
    );
    return CustomScrollView(
      // 아래 시트와 오른쪽 패널이 같은 키를 써서, 기기를 돌려 틀이 바뀌어도 넘긴 자리가 남는다.
      key: const PageStorageKey('candidate-list'),
      // 지도에서 누른 후보로 넘기려면 화면 밖 줄도 만들어 두어야 한다.
      scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
      slivers: [
        if (candidates.isEmpty)
          SliverPadding(
            padding: side.add(const EdgeInsets.all(AppSpace.sm)),
            sliver: SliverToBoxAdapter(
              child: Text(
                context.l10n.candidateListEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: side,
          sliver: SliverList.list(
            children: [
              for (final candidate in candidates)
                CandidateTile(
                  key: _keys[candidate.id] ??= GlobalKey(),
                  candidate: candidate,
                  look: candidateLookOf(candidate.kind, colors),
                  expanded: selection.expanded == candidate.id,
                  highlighted: selection.highlighted.contains(candidate.id),
                  onToggle: () => selection.tapStop(candidate.id),
                  onOpenMap: () => widget.onOpenMap(candidate),
                  // 목록에서 누른 줄에만 연필이 보인다(일차 동선 목록과 같다).
                  onEdit: onEdit != null && selection.active == candidate.id
                      ? () => onEdit(candidate)
                      : null,
                  actions: onPromote == null
                      ? null
                      : FilledButton.tonalIcon(
                          onPressed: () => onPromote(candidate),
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(context.l10n.candidatePromote),
                        ),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: widget.padding.bottom + AppSpace.lg),
        ),
      ],
    );
  }
}

/// 후보 목록의 제목 줄: "후보 장소"와 후보 수.
///
/// 아래 시트는 위에 끌기 손잡이를([showHandle]), 오른쪽 패널은 끝에 닫기 버튼을([onClose]) 단다.
class CandidateHeader extends StatelessWidget {
  const CandidateHeader({
    super.key,
    required this.count,
    this.showHandle = false,
    this.onClose,
  });

  final int count;
  final bool showHandle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;
    final onClose = this.onClose;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        onClose == null ? AppSpace.lg : AppSpace.xs,
        onClose == null ? AppSpace.md : AppSpace.xs,
      ),
      child: Column(
        children: [
          if (showHandle) ...[
            Container(
              width: AppSpace.xxl,
              height: AppSpace.xs,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: AppRadius.sm,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          Row(
            children: [
              Container(
                width: AppSpace.md,
                height: AppSpace.md,
                decoration: BoxDecoration(
                  color: colors.routeCandidate.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.routeCandidateRing),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  l10n.candidateListTitle,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.candidateCount(count),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

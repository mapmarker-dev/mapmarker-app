import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/time/local_date.dart';
import '../../core/time/today.dart';
import '../../data/models/trip.dart';
import '../../l10n/l10n.dart';
import 'trip_create_controller.dart';

/// 여행 만들기. 지역은 꼭 넣고, 기간은 넣지 않아도 된다.
class TripCreateScreen extends ConsumerStatefulWidget {
  const TripCreateScreen({super.key});

  @override
  ConsumerState<TripCreateScreen> createState() => _TripCreateScreenState();
}

class _TripCreateScreenState extends ConsumerState<TripCreateScreen> {
  late final _title = TextEditingController(
    text: ref.read(tripCreateProvider).title,
  );
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final today = ref.read(todayProvider);
    final dates = ref.read(tripCreateProvider).dates;
    final range = await showDateRangePicker(
      context: context,
      // 지난 여행도 기록할 수 있게 과거 날짜를 고를 수 있다.
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 5, 12, 31),
      currentDate: today.toDateTime(),
      initialDateRange: dates == null
          ? null
          : DateTimeRange(
              start: dates.start.toDateTime(),
              end: dates.end.toDateTime(),
            ),
    );
    if (range == null || !mounted) return;
    ref
        .read(tripCreateProvider.notifier)
        .setDates(
          TripDates(
            LocalDate.fromDateTime(range.start),
            LocalDate.fromDateTime(range.end),
          ),
        );
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final trip = await ref.read(tripCreateProvider.notifier).create();
      if (mounted) context.go(Routes.trip(trip.id));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = ref.watch(tripCreateProvider);
    final controller = ref.read(tripCreateProvider.notifier);
    final today = ref.watch(todayProvider);
    // 제목을 고치기 전에는 입력을 따라 바뀐 제목을 칸에 채운다.
    ref.listen(tripCreateProvider.select((draft) => draft.title), (_, title) {
      if (_title.text != title) _title.text = title;
    });

    final dates = draft.dates;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTripScreenTitle)),
      body: ListView(
        // 시스템 막대만큼 더 띄워서 맨 아래 만들기 버튼이 가리지 않게 한다.
        padding:
            const EdgeInsets.all(AppSpace.lg) + MediaQuery.paddingOf(context),
        children: [
          TextField(
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.regionLabel,
              hintText: l10n.regionHint,
            ),
            onChanged: controller.setRegion,
          ),
          _SectionTitle(l10n.datesSectionTitle),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  dates == null ? l10n.pickDates : l10n.tripDatesText(dates),
                ),
                onPressed: _pickDates,
              ),
              if (dates != null)
                IconButton(
                  tooltip: l10n.clearDates,
                  icon: const Icon(Icons.close),
                  onPressed: controller.clearDates,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            dates == null
                ? l10n.phasePreviewUndated(l10n.tripPhaseName(TripPhase.before))
                : l10n.phasePreviewFromDates(
                    l10n.tripPhaseName(dates.phaseOn(today)),
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _SectionTitle(l10n.lengthSectionTitle),
          if (dates != null)
            Text(l10n.nightsText(draft.nights))
          else
            Row(
              children: [
                IconButton(
                  tooltip: l10n.removeNight,
                  icon: const Icon(Icons.remove),
                  onPressed: draft.nights > 0
                      ? () => controller.setNights(draft.nights - 1)
                      : null,
                ),
                Text(l10n.nightsText(draft.nights)),
                IconButton(
                  tooltip: l10n.addNight,
                  icon: const Icon(Icons.add),
                  onPressed: draft.nights < TripCreateController.maxNights
                      ? () => controller.setNights(draft.nights + 1)
                      : null,
                ),
              ],
            ),
          _SectionTitle(l10n.seasonSectionTitle),
          Wrap(
            spacing: 8,
            children: [
              for (final season in Season.values)
                ChoiceChip(
                  label: Text(l10n.seasonName(season)),
                  selected: draft.season == season,
                  onSelected: (_) => controller.setSeason(season),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.titleLabel,
              hintText: l10n.defaultTripTitle(
                region: draft.region,
                nights: draft.nights,
                season: draft.season,
              ),
              helperText: l10n.titleHelperOnCreate,
            ),
            onChanged: controller.editTitle,
          ),
          const SizedBox(height: AppSpace.xxl),
          FilledButton(
            onPressed: draft.canCreate && !_saving ? _create : null,
            child: Text(l10n.createTripButton),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

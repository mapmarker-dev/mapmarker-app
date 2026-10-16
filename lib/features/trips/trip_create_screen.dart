import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/time/local_date.dart';
import '../../core/time/today.dart';
import '../../data/models/trip.dart';
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
      currentDate: _toDateTime(today),
      initialDateRange: dates == null
          ? null
          : DateTimeRange(
              start: _toDateTime(dates.start),
              end: _toDateTime(dates.end),
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
    final draft = ref.watch(tripCreateProvider);
    final controller = ref.read(tripCreateProvider.notifier);
    final today = ref.watch(todayProvider);
    // 제목을 고치기 전에는 입력을 따라 바뀐 제목을 칸에 채운다.
    ref.listen(tripCreateProvider.select((draft) => draft.title), (_, title) {
      if (_title.text != title) _title.text = title;
    });

    final dates = draft.dates;
    return Scaffold(
      appBar: AppBar(title: const Text('새 여행')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '지역',
              hintText: '예: 부산',
            ),
            onChanged: controller.setRegion,
          ),
          const _SectionTitle('기간 (선택)'),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(dates?.label ?? '날짜 고르기'),
                onPressed: _pickDates,
              ),
              if (dates != null)
                IconButton(
                  tooltip: '날짜 지우기',
                  icon: const Icon(Icons.close),
                  onPressed: controller.clearDates,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dates == null
                ? '상태: ${TripPhase.before.label} (날짜 미정)'
                : '상태: ${dates.phaseOn(today).label} (기간으로 자동)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const _SectionTitle('일정'),
          if (dates != null)
            Text(formatNights(draft.nights))
          else
            Row(
              children: [
                IconButton(
                  tooltip: '1박 줄이기',
                  icon: const Icon(Icons.remove),
                  onPressed: draft.nights > 0
                      ? () => controller.setNights(draft.nights - 1)
                      : null,
                ),
                Text(formatNights(draft.nights)),
                IconButton(
                  tooltip: '1박 늘리기',
                  icon: const Icon(Icons.add),
                  onPressed: draft.nights < TripCreateController.maxNights
                      ? () => controller.setNights(draft.nights + 1)
                      : null,
                ),
              ],
            ),
          const _SectionTitle('계절'),
          Wrap(
            spacing: 8,
            children: [
              for (final season in Season.values)
                ChoiceChip(
                  label: Text(season.label),
                  selected: draft.season == season,
                  onSelected: (_) => controller.setSeason(season),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: '제목',
              hintText: draft.defaultTitle,
              helperText: '비우면 기본 제목으로 만듭니다.',
            ),
            onChanged: controller.editTitle,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: draft.canCreate && !_saving ? _create : null,
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }
}

DateTime _toDateTime(LocalDate date) =>
    DateTime(date.year, date.month, date.day);

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

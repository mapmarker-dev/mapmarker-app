import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/trip.dart';
import 'trip_detail_controller.dart';
import 'widgets/rename_trip_dialog.dart';

/// 여행 동선 페이지. 지금은 제목만 보이고, 지도는 다음 단위에서 들어온다.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  Future<void> _rename(BuildContext context, WidgetRef ref, Trip trip) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) =>
          RenameTripDialog(title: trip.title, defaultTitle: trip.defaultTitle),
    );
    if (title == null || !context.mounted) return;
    await ref.read(tripDetailProvider(tripId).notifier).rename(title);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(tripDetailProvider(tripId))) {
      AsyncData(value: final trip?) => Scaffold(
        appBar: AppBar(
          title: Text(trip.title),
          actions: [
            IconButton(
              tooltip: '제목 바꾸기',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(context, ref, trip),
            ),
          ],
        ),
        body: const SizedBox.shrink(),
      ),
      AsyncData() => const _Message('여행을 찾을 수 없습니다.'),
      AsyncError() => const _Message('여행을 불러오지 못했습니다.'),
      AsyncLoading() => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(text)),
    );
  }
}

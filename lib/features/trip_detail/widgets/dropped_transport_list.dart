import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/segment.dart';
import '../../../data/models/trip_route.dart';
import '../../../l10n/l10n.dart';

/// 지워질 이동 수단. 구간마다 어느 일차의 어느 구간인지(예: "2일차 용두암 → 동문시장")와 그 이동 수단을 적는다.
///
/// 이동 수단이 사라진다고 묻는 대화상자(끌어 옮기기, 연박)와 장소 입력 화면의 미리 알림이 함께 쓴다.
class DroppedTransportList extends StatelessWidget {
  const DroppedTransportList({
    super.key,
    required this.route,
    required this.segments,
  });

  /// 구간 글자를 만들 동선. 옮기거나 넣기 전의 동선이다.
  final TripRoute route;

  final List<Segment> segments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in segments)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (l10n.segmentRouteText(route, segment) case final text?)
                  Text(text, style: textTheme.titleSmall),
                Text(
                  l10n.transportText(segment),
                  style: textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

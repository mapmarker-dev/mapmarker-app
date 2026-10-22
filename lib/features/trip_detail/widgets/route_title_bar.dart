import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';

/// 지도 위에 뜨는 제목 카드. 뒤로 가기, 제목과 그 아래 한 줄(상태·기간·일정), 제목 바꾸기가 있다.
class RouteTitleBar extends StatelessWidget {
  const RouteTitleBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRename,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(color: context.appColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          children: [
            const BackButton(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.renameTrip,
              icon: const Icon(Icons.edit_outlined),
              onPressed: onRename,
            ),
          ],
        ),
      ),
    );
  }
}

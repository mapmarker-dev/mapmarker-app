import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';

/// 지도 위에 뜨는 제목 카드. 뒤로 가기, 제목과 그 아래 한 줄(상태·기간·일정), 이미지 만들기, 제목 바꾸기가 있다.
class RouteTitleBar extends StatelessWidget {
  const RouteTitleBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRename,
    required this.onExport,
  });

  final String title;
  final String subtitle;

  /// 제목 바꾸기. null이면 연필이 없다(샘플 여행).
  final VoidCallback? onRename;

  /// 이미지 만들기. 샘플 여행에도 있다(저장하는 것이 없다).
  final VoidCallback onExport;

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
              tooltip: context.l10n.exportOpen,
              icon: const Icon(Icons.image_outlined),
              onPressed: onExport,
            ),
            if (onRename case final onRename?)
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

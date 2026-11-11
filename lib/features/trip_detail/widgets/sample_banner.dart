import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/saving.dart';
import '../../../l10n/l10n.dart';

/// 샘플 여행 위에 뜨는 안내. 보기만 된다는 것과, 내 여행으로 가져가는 [실제로 사용하기] 버튼.
class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key, required this.onUse, required this.using});

  final VoidCallback onUse;

  /// 내 여행으로 복사하는 중. 장소가 많아 몇 초 걸려서 버튼에 진행 표시를 띄운다.
  final bool using;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(color: context.appColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.sampleBanner,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            FilledButton(
              onPressed: using ? null : onUse,
              child: using
                  ? SavingIndicator(label: l10n.saving, padded: false)
                  : Text(l10n.useSample),
            ),
          ],
        ),
      ),
    );
  }
}

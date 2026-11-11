import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 저장을 기다리는 동안의 작은 진행 표시.
///
/// [padded]면 연필·손잡이 같은 작은 버튼(40px)과 같은 자리를 차지해서, 버튼 대신 띄워도 모양이 바뀌지 않는다.
class SavingIndicator extends StatelessWidget {
  const SavingIndicator({
    super.key,
    required this.label,
    this.size = 18,
    this.padded = true,
    this.color,
  });

  /// 읽어 주기 글. 예: "저장하는 중".
  final String label;

  final double size;
  final bool padded;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
        semanticsLabel: label,
      ),
    );
    if (!padded) return spinner;
    return SizedBox.square(
      dimension: AppSpace.xxl + AppSpace.sm,
      child: Center(child: spinner),
    );
  }
}

/// 입력 화면 안에 띄우는 저장 실패 안내.
///
/// 입력 화면은 저장되기 전까지 닫지 않는다. 그래서 실패는 아래 화면의 스낵바가 아니라 입력 화면 안에서 알린다.
class SaveErrorBanner extends StatelessWidget {
  const SaveErrorBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: AppRadius.md,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

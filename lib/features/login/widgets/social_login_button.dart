import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// 카카오·네이버 로그인 버튼. 두 회사의 버튼 규칙대로 브랜드 바탕색에 공식 심볼과 글자를 놓는다.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.symbolAsset,
    required this.colors,
    required this.onPressed,
    this.busy = false,
  });

  static const _height = 52.0;
  static const _symbolSize = 20.0;

  final String label;

  /// 공식 심볼 이미지.
  final String symbolAsset;

  /// 바탕은 브랜드 색, 글자는 그 위 글자색.
  final ChipColors colors;

  /// null이면 누를 수 없다(다른 로그인이 진행 중).
  final VoidCallback? onPressed;

  /// 이 버튼의 로그인이 진행 중이다. 심볼 대신 진행 표시가 뜬다.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.background,
          foregroundColor: colors.foreground,
          disabledBackgroundColor: colors.background.withValues(alpha: 0.5),
          disabledForegroundColor: colors.foreground.withValues(alpha: 0.5),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: _symbolSize,
              child: busy
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.foreground,
                    )
                  : Image.asset(
                      symbolAsset,
                      excludeFromSemantics: true,
                      // 이미지가 없어도 글자만으로 버튼은 쓸 수 있다.
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(label),
          ],
        ),
      ),
    );
  }
}

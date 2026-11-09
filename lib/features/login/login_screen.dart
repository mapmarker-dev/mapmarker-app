import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/auth/account.dart';
import '../../data/auth/social_sdk.dart';
import '../../l10n/l10n.dart';
import 'login_controller.dart';
import 'widgets/social_login_button.dart';

/// 로그인. 앱 이름과 카카오·네이버 버튼만 둔다. 로그인하면 바로 여행 목록으로 간다.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  /// 넓은 화면에서 버튼이 너무 길어지지 않게 한다.
  static const _maxWidth = 400.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final busy = ref.watch(loginProvider);

    Widget button(
      SocialProvider provider, {
      required String label,
      required String symbol,
      required ChipColors brand,
    }) => SocialLoginButton(
      label: label,
      symbolAsset: symbol,
      colors: brand,
      busy: busy == provider,
      onPressed: busy == null ? () => _logIn(context, ref, provider) : null,
    );

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(AppSpace.xl) + MediaQuery.paddingOf(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'MapMarker',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: AppFont.extraBold,
                  ),
                ),
                const SizedBox(height: AppSpace.xxl * 2),
                button(
                  SocialProvider.kakao,
                  label: l10n.loginWithKakao,
                  symbol: 'assets/login/kakao_symbol.png',
                  brand: colors.kakaoLogin,
                ),
                const SizedBox(height: AppSpace.md),
                button(
                  SocialProvider.naver,
                  label: l10n.loginWithNaver,
                  symbol: 'assets/login/naver_symbol.png',
                  brand: colors.naverLogin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logIn(
    BuildContext context,
    WidgetRef ref,
    SocialProvider provider,
  ) async {
    final failure = await ref.read(loginProvider.notifier).logIn(provider);
    if (failure == null || !context.mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (failure) {
          LoginFailure.network => l10n.loginFailedNetwork,
          LoginFailure.unavailable => l10n.loginFailedUnavailable,
          LoginFailure.rejected => l10n.loginFailedRetry,
        }),
      ),
    );
  }
}

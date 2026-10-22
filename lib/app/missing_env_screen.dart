import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

class MissingEnvScreen extends StatelessWidget {
  const MissingEnvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: Text(
            'NAVER_MAP_CLIENT_ID가 없습니다.\n'
            '.env를 채우고 flutter run --dart-define-from-file=.env 로 실행하세요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

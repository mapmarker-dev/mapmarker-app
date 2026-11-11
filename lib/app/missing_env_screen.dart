import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';

/// 개발자용 안내. `.env` 값이 비어 있을 때 앱 대신 뜬다.
class MissingEnvScreen extends StatelessWidget {
  const MissingEnvScreen({super.key, required this.names});

  /// 비어 있는 값의 이름.
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Text(
            '${names.join(', ')} 값이 없습니다.\n'
            '.env를 채우고 flutter run --dart-define-from-file=.env 로 실행하세요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

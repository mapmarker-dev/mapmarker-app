import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen texts use no middle dot', () {
    // 화면 글자에는 가운뎃점(·)을 쓰지 않는다(사용자 결정). 쉼표, "과"와 "와", "나", 괄호로 쓴다.
    // "@" 항목(설명)은 화면에 나오지 않아 보지 않는다.
    final arb =
        jsonDecode(File('lib/l10n/app_ko.arb').readAsStringSync())
            as Map<String, dynamic>;
    final dotted = [
      for (final MapEntry(:key, :value) in arb.entries)
        if (!key.startsWith('@') && value is String && value.contains('·')) key,
    ];

    expect(dotted, isEmpty);
  });
}

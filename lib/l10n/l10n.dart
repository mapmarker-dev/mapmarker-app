import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';
export 'model_texts.dart';

/// 지금은 한국어만 지원한다.
///
/// 영어를 넣을 때 기기 언어를 따를지 정하고, [l10nProvider]도 화면과 같은 언어를 쓰게 바꾼다.
const appLocale = Locale('ko');

/// 화면 밖(컨트롤러)에서 쓰는 글자. 화면에서는 `context.l10n`을 쓴다.
final l10nProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(appLocale),
);

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

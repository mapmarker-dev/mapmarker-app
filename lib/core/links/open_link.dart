import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// 링크를 앱 밖(브라우저나 그 링크를 맡는 앱)에서 연다. 열지 못하면 false다.
typedef OpenLink = Future<bool> Function(Uri uri);

/// 테스트에서는 여는 대신 받은 링크를 기록하는 함수로 바꿔 끼운다.
final openLinkProvider = Provider<OpenLink>((ref) => _openExternally);

Future<bool> _openExternally(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}

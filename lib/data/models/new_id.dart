import 'package:uuid/uuid.dart';

/// 새 ID. 앱에서 UUID v7(만든 시각 순서)로 만들고, 서버는 그대로 쓴다.
String newId() => _uuid.v7();

const _uuid = Uuid();

import 'dart:async';

import 'package:mapmarker_app/core/location/location_source.dart';

/// 기기 위치 대신 쓰는 가짜. 실제 GPS와 권한 창에 붙지 않는다.
///
/// - [granted]: 권한이 이미 있는지. 기본은 없음이라, 화면을 열기만 하면 위치를 받지 않는다.
/// - [answer]: 권한을 물었을 때 사용자의 대답. null이면 허용이다(그 뒤 [granted]가 된다).
/// - [serviceOff]: 위치 서비스가 꺼져 있다.
/// - [emit]으로 위치를 낸다. 듣는 중이 아니면 버린다.
class FakeLocationSource implements LocationSource {
  FakeLocationSource({
    this.granted = false,
    this.answer,
    this.serviceOff = false,
  });

  bool granted;
  LocationProblem? answer;
  bool serviceOff;

  /// 권한 창을 띄운 횟수.
  int asked = 0;

  /// 앱 설정, 위치 설정을 연 횟수.
  int openedAppSettings = 0;
  int openedLocationSettings = 0;

  final _positions = StreamController<LocationFix>.broadcast();

  /// 지금 위치를 듣는 중인지.
  bool get listening => _positions.hasListener;

  void emit(LocationFix fix) => _positions.add(fix);

  @override
  Future<LocationProblem?> prepare({required bool ask}) async {
    if (serviceOff) return LocationProblem.serviceOff;
    if (granted) return null;
    if (!ask) return LocationProblem.denied;
    asked++;
    final answer = this.answer;
    if (answer == null) granted = true;
    return answer;
  }

  @override
  Stream<LocationFix> positions() => _positions.stream;

  @override
  Future<void> openAppSettings() async => openedAppSettings++;

  @override
  Future<void> openLocationSettings() async => openedLocationSettings++;
}

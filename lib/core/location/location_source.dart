import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../map/geo.dart';

/// 기기의 현재 위치. 화면은 이 인터페이스만 쓰고, 테스트는 가짜로 바꿔 끼운다(실제 기기 위치에 붙지 않는다).
///
/// 권한은 "앱 사용 중"만 쓴다(OVERVIEW "지도, 외부 서비스, AI"). 백그라운드 위치와 기록은 없다.
abstract interface class LocationSource {
  /// 위치를 받을 수 있는지 본다. [ask]면 권한이 없을 때 시스템 창으로 묻는다.
  /// 받을 수 있으면 null, 아니면 그 이유다.
  Future<LocationProblem?> prepare({required bool ask});

  /// 위치가 바뀔 때마다 낸다. [prepare]가 null을 낸 뒤에 듣는다. 듣기를 멈추면 위치 받기도 멈춘다.
  Stream<LocationFix> positions();

  /// 이 앱의 설정 화면(권한)을 연다.
  Future<void> openAppSettings();

  /// 기기의 위치 서비스 설정을 연다.
  Future<void> openLocationSettings();
}

/// 위치를 받지 못한 이유. 이유마다 안내 문구와 [설정] 버튼이 다르다.
enum LocationProblem {
  /// 권한을 거부했다(다시 물을 수 있다).
  denied,

  /// 다시 묻지 않음으로 거부했다. 설정에서만 바꾼다.
  deniedForever,

  /// 기기의 위치 서비스(GPS)가 꺼져 있다.
  serviceOff,
}

/// 받은 위치. [accuracy]는 미터 단위 오차 반경이다(대략적인 위치만 허용하면 크다).
@immutable
class LocationFix {
  const LocationFix(this.position, {this.accuracy = 0});

  final LatLng position;
  final double accuracy;

  @override
  bool operator ==(Object other) =>
      other is LocationFix &&
      other.position == position &&
      other.accuracy == accuracy;

  @override
  int get hashCode => Object.hash(position, accuracy);

  @override
  String toString() => 'LocationFix($position, ±${accuracy}m)';
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => GeolocatorLocationSource(),
);

/// geolocator로 받는다(Android, iOS).
class GeolocatorLocationSource implements LocationSource {
  /// 이만큼 움직여야 새 위치를 낸다(m). 걸으며 볼 만큼 자주, 배터리를 덜 쓰게.
  static const distanceFilter = 10;

  @override
  Future<LocationProblem?> prepare({required bool ask}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationProblem.serviceOff;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.whileInUse || LocationPermission.always => null,
      LocationPermission.deniedForever => LocationProblem.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => LocationProblem.denied,
    };
  }

  @override
  Stream<LocationFix> positions() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          distanceFilter: distanceFilter,
        ),
      ).map(
        (p) =>
            LocationFix(LatLng(p.latitude, p.longitude), accuracy: p.accuracy),
      );

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

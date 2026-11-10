import 'package:mapmarker_app/data/sample/jeju_sample.dart';
import 'package:mapmarker_app/data/sample/sample_store.dart';
import 'package:mapmarker_app/data/sample/sample_trip_repository.dart';
import 'package:mapmarker_app/data/trips/trip_repository.dart';

import 'test_app.dart';

/// 기기 대신 메모리에 샘플을 숨겼는지 기억한다.
class MemorySampleStore implements SampleStore {
  bool hidden = false;
  int hides = 0;

  @override
  Future<bool> isHidden() async => hidden;

  @override
  Future<void> hide() async {
    hidden = true;
    hides++;
  }
}

/// [inner]에 제주 샘플을 더한 저장소. 앱에서 로그인한 동안과 같다.
SampleTripRepository withSample(
  TripRepository inner,
  MemorySampleStore store,
) => SampleTripRepository(
  inner: inner,
  store: store,
  sample: jejuSample(testL10n),
);

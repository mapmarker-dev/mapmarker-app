/// 화면 이동에 쓰는 경로.
abstract final class Routes {
  static const tripList = '/';
  static const tripCreate = '/trips/new';
  static String trip(String tripId) => '/trips/$tripId';
  static const snapshotLab = '/dev/snapshot-lab';
}

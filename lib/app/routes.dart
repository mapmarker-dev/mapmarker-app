/// 화면 이동에 쓰는 경로.
abstract final class Routes {
  static const login = '/login';
  static const tripList = '/';
  static const tripCreate = '/trips/new';
  static String trip(String tripId) => '/trips/$tripId';

  /// 이미지 만들기. [day]는 처음 고를 일차(없으면 전체), [lodging]은 숙소를 넣을지다.
  static String tripExport(String tripId, {int? day, bool lodging = true}) {
    final query = {
      if (day != null) 'day': '$day',
      if (!lodging) 'lodging': '0',
    };
    return Uri(
      path: '/trips/$tripId/export',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static const trash = '/trash';
}

import 'geo.dart';

/// 외부 지도 앱·웹에서 장소를 여는 링크. 지도 SDK 없이 만들어서 `naver/` 밖에 둔다.
///
/// MVP에는 Places 연동이 없어서 장소 ID 대신 이름과 좌표로 찾는다.
/// 구글 맵 링크는 2단계에 placeId와 함께 추가한다.

/// 네이버 지도 웹에서 [position] 주변을 [name]으로 찾는 링크.
///
/// 네이버가 가진 장소 페이지(영업시간, 리뷰)로 이어진다. 네이버 지도 앱이 있으면 앱이 열 수도 있다.
/// `c`는 지도 가운데(경도, 위도)와 줌이다. 뒤의 `0,0,0,dh`는 회전·기울기 없는 기본 지도다.
Uri naverMapSearchUri(String name, LatLng position) => Uri(
  scheme: 'https',
  host: 'map.naver.com',
  pathSegments: ['p', 'search', name.trim()],
  // queryParameters로 넣으면 쉼표가 %2C로 바뀐다. 쉼표는 쿼리에 그대로 써도 된다.
  query:
      'c=${position.longitude.toStringAsFixed(7)},'
      '${position.latitude.toStringAsFixed(7)},15,0,0,0,dh',
);

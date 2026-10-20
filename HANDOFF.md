# HANDOFF

> 최종 갱신: 2026-10-20 · 브랜치: dev

## 지금 하는 일

여행 동선 페이지와 `MapProvider`(네이버) 단위를 마쳤다. 진행 방향 화살표도 앞당겨 넣었다(사용자 요청).
- 갤럭시 탭과 갤럭시 휴대폰에서 장소·숙소 마커, 선, 화살표가 보이는 것을 확인했다.
- `.github` PLAN 1-2의 세 항목(`MapProvider`, 여행 동선 페이지, 진행 방향 화살표)을 완료로 체크했다.
- 화살표가 나타나는 줌을 바꾸려면 `core/map/route_arrow.dart`의 `arrowMinLineLength`(72)를 조정한다.
- 지도는 `core/map/`(인터페이스, 좌표·카메라 범위, 화살표 계산, 마커·화살표 그림)와 `core/map/naver/`(네이버 구현)에 있다.
- 동선 규칙(출발 숙소, 숙소 끄기, 번호)은 `data/models/trip_route.dart`, 구간 자동 연결은 `data/trips/route_links.dart`에 있다.
- 샘플 여행: 제주(숙소 연박, 3일차에 숙소를 옮김, 종류 4개 모두), 부산(2일차 비움), 강릉(장소 없음).

## 다음에 할 첫 단계

1. 장소 편집·상세 시트 단위.
   - 장소 편집: 지도를 탭해서 추가, 종류 고르기, "어제 숙소 그대로", 순서 바꾸기, 삭제. 저장소 메서드는 이미 있다.
   - 마커 탭과 지도 탭 콜백은 이때 `MapProvider`에 추가한다.
2. 그다음 순서 후보: 구간·이동 수단 → 곡선 핸들 → 서버 연동·로그인.
   - 곡선 단위에서는 화살표에도 곡률을 넘긴다(`routeArrow`의 `curvature`). 지금은 선이 직선이라 넘기지 않는다.

## 현재 상태

- `flutter analyze` 문제 0건, `flutter test` 167개 통과. 테마 테스트가 글자와 바탕의 대비(4.5:1 이상)를 확인한다.
- 내보내기 합성(`features/export/route_composer.dart`, 0단계 프로토타입)은 아직 자기 색(파랑 #1E6FFF)과 글꼴 크기를 쓴다. 1-5단계에서 토큰으로 바꾼다.
- 디버그 빌드는 시작할 때 샘플 여행 3개와 그 장소를 넣는다(`lib/dev/sample_trips.dart`, `main.dart`).
  - 오늘 기준 제주(중), 강릉(전, 날짜 미정), 부산(후)이다.
  - 테스트는 빈 저장소로 시작한다.
- `flutter_naver_map`은 `core/map/naver/`, `main.dart`(SDK 초기화), `dev/snapshot_lab/`에서만 쓴다. 나머지 코드는 `MapProvider`만 본다.

## 아직 문서에 없는 결정

- **디자인**
  - 글꼴은 공식 배포본의 TTF 3개(보통·굵게·아주 굵게)만 원본 그대로 넣었다(앱 약 3MB 증가). 가는 굵기는 쓰지 않아서 뺐다.
  - 배포본 ZIP에는 라이선스 파일이 없다. 그래서 네이버 나눔 글꼴 공통 OFL 고지(예약 이름에 `NanumSquareRound` 포함)와 OFL 1.1 전문을 `assets/fonts/OFL.txt`로 넣었다.
  - 카드는 그림자 없이 테두리만 둔다. 여행 중인 카드만 코랄 테두리로 강조한다.
  - 동선 선의 색은 도착 장소의 일차 색이다. 전날 숙소에서 나오는 길은 다음 날 아침의 이동이라 다음 날 색이다.
  - 숙소 마커는 일차 색이 아니라 숙소 전용 색이다. 숙소는 이틀에 걸쳐 쓰이기 때문이다.
- **화면 동작**
  - 여행 목록은 최근에 만들거나 고친 순서다. 상태를 바꿔도, 장소를 바꿔도 위로 올라간다(채팅 앱 목록처럼).
  - 상태 변경 UI는 목록의 상태 칩 메뉴에만 있다. 동선 페이지는 상태를 제목 아래 글자로만 보여 준다.
  - 제목 바꾸기는 동선 페이지 제목 카드의 연필 버튼이다. 칸을 비우면 기본 제목으로 돌아간다.
- **동선 페이지**
  - 카메라는 세 경우에만 맞춘다: 처음 열 때, 일차·숙소 칩을 누를 때(지금 일차를 다시 눌러도), 맞추기 버튼을 누를 때.
    - 장소가 바뀌어도 카메라는 그대로 둔다. 다음 단위에서 장소를 편집할 때 화면이 튀지 않게 하려는 것이다.
  - 장소가 하나뿐이거나 모여 있으면 카메라 범위를 약 550m(0.005도)까지 넓힌다. 장소가 없는 여행은 한국 전체를 보여 준다.
  - 장소 번호는 숙소가 아닌 장소에 일차마다 1부터 붙인다. 숙소를 켜고 꺼도 번호가 바뀌지 않게 하려는 것이다.
  - 출발 숙소는 "앞 일차의 마지막 장소가 숙소일 때"다. 장소가 없는 일차도 그 숙소를 보여 준다.
  - 숙소를 끄면 낮에 들른 숙소(장소 > 숙소 > 장소)의 앞뒤 선이 끊긴다. 가지 않은 직선을 만들어 긋지 않으려는 것이다.
  - 축척 막대와 실내 지도는 껐다.
  - 진행 방향 화살표는 구간마다 하나, 선 가운데에 둔다.
    - 끝점에 두면 도착 장소 마커에 가린다.
    - 선이 화면에서 72px보다 짧아지는 줌에서는 숨긴다. 멀리서 보면 화살표가 마커와 겹치기 때문이다.
    - 이 줌은 "줌 0에서 세계 지도 한 변이 256px"로 보고 계산했다.
  - 화살표는 지도와 함께 도는 평평한 마커다. 선 위, 장소 마커 아래에 그린다.
- **여행 만들기**
  - 기간이 있으면 일정은 고정되고, 계절은 시작일 기준으로 자동 선택되지만 바꿀 수 있다(11월 말처럼 경계에 걸린 달 때문).
  - 기간이 없으면 일정은 −/+ 버튼으로 고른다(기본 1박 2일, 당일치기~30박). 계절은 기본값 없이 꼭 고르게 했다. 틀린 계절이 제목에 들어가지 않게 하려는 것이다.
  - 날짜는 과거 10년부터 앞으로 5년까지 고를 수 있다. 지난 여행도 기록할 수 있게 하려는 것이다.
- **저장소:** `TripRepository`는 화면이 구독하는 스트림과 쓰기 메서드로 되어 있다. 화면끼리 서로 갱신을 알리지 않아도 되게 하려는 것이다.
  - 여행: `watchTrips`·`watchTrip`, `createTrip`·`updateTrip`.
  - 동선: `watchRoute`, 장소 추가·수정·이동·삭제, 구간 수정.
  - 장소와 구간은 한 스트림(`TripRoute`)으로 낸다. 둘이 어긋난 중간 상태가 화면에 보이지 않게 하려는 것이다.
  - 서버 구현은 받아 온 여행을 기억해 두고, 이 앱에서 바꾼 내용을 반영해 다시 내보내야 한다. 이 부분은 2-2단계 오프라인 보기와 함께 설계한다.
- 서버가 생기기 전에는 디버그 빌드에서만 샘플 여행을 넣는다. 메모리 저장소는 앱을 끄면 비기 때문이다.
- 앱 언어는 `appLocale`(ko)로 고정했다(`lib/l10n/l10n.dart`).
  - 영어를 넣을 때 기기 언어를 따를지 정한다.
  - 그때 `MaterialApp`의 `locale`과 컨트롤러가 쓰는 `l10nProvider`가 같은 언어를 쓰게 맞춘다.
- 구간의 이동 수단은 고르지 않아도 된다. 비어 있으면 "미정"이다.
- 걸리는 시간은 "3시간 20분"처럼 적는다.
- 앱에는 Android·iOS 폴더만 남겼다(`linux/`, `macos/`, `windows/`, `web/`는 지웠다). 네이버 지도 SDK가 두 플랫폼만 지원하기 때문이다. 이 폴더들이 로컬에 비어서 남아 있으면 `flutter pub get` 때 플러그인 등록 파일이 다시 생기니 지운다.
- 앱 표시 이름은 `MapMarker`다(Android `android:label`, iOS `CFBundleDisplayName`).
- 1단계 경로: `/login`, `/`, `/trips/new`, `/trips/:tripId`(일차 전환은 화면 상태), `/trips/:tripId/export`, `/settings`. 3단계에 `/shared/:shareId`(공유 링크 `/trip/<공유ID>`를 redirect로 연결). 장소 상세는 경로가 아니라 바텀 시트다.
- `MapProvider`는 Riverpod의 Provider와 이름이 겹치지만, 문서에 맞추려고 그대로 둔다.
  - Riverpod 쪽 이름은 `mapProviderProvider`(지도 종류별 family, `core/map/map_registry.dart`)다.
  - 어느 지도인지 나타내는 enum은 `MapProviderType`이다. 여행의 지도와 Stop의 `placeProvider`에 함께 쓴다.
- **go_router는 17.x에 묶어 둔다.**
  - go_router 18은 Material을 새 `material_ui` 패키지로 옮겼다. 그래서 `package:flutter/material.dart`의 `MaterialApp`을 쓰는 앱은 MaterialApp으로 알아보지 못하고, 모든 화면을 전환 애니메이션 없는 `NoTransitionPage`로 띄운다.
  - Flutter 3.47 새 프로젝트 템플릿과 `flutter_naver_map`(로고 위젯 포함)이 아직 `flutter/material`을 쓴다. 그래서 앱도 거기에 맞췄다.
  - 플러그인들이 `material_ui`로 옮기면 앱 import와 함께 18로 올린다. 18로 올리면 `test/app/router_test.dart`의 Material 페이지 테스트가 실패한다.

## 결론이 안 난 논의

- 이동 수단의 선 모양과 아이콘, "미정" 구간의 선, 갈아타는 구간(예: 지하철 2정류장 + 도보)을 어느 수단 모양으로 그릴지는 구간·이동 수단 단위에서 정한다.
- 숙소가 아닌 장소를 같은 자리에 두 번 넣으면 전체 보기에서 마커가 겹친다. 예: 제주국제공항(1일차 1번, 4일차 2번), 부산역. 같은 자리의 숙소만 마커 하나로 합친다. 장소 편집·상세 시트 단위에서 마커 탭과 함께 처리 방법을 정한다.
- 카드에 동선 미리보기나 사진을 넣을지는 1-5단계(이미지 내보내기) 때 다시 본다.
- 영어를 넣는 시점과 언어를 고르는 방식은 아직 정하지 않았다(`PLAN.md` "아직 확인할 것").
- 남반구 해외 여행에서는 계절이 반대가 된다. 2단계에서 다시 본다.

## 주의할 점

- **시스템 막대 여백(SafeArea)**
  - Android 15 이상에서는 targetSdk 35 이상 앱이 화면 끝까지 그려진다(edge-to-edge). 앱은 Flutter 3.47 기본값인 targetSdk 36이다.
  - targetSdk를 낮춰서 피할 수 없다. Google Play는 API 35 이상을 요구하고, targetSdk 36에서는 edge-to-edge를 끄는 설정도 막혔다.
  - 위쪽 상태 표시줄은 `AppBar`가 비켜 준다.
  - 아래·옆(내비게이션 막대, 홈 표시줄, 가로 화면의 카메라 구멍)은 스크롤 여백에 시스템 여백을 더해서 비킨다(규칙은 `CLAUDE.md` "디자인").
  - 목록과 만들기 화면의 여백은 갤럭시 휴대폰·탭에서 확인했다.
  - Android 14 이하에서는 막대가 화면을 가리지 않아서 차이가 안 보인다. 0단계에서 확인한 탭과 휴대폰은 Android 14와 10이었다.
  - 테스트에서는 `showNavigationBar`(`test/helpers/test_app.dart`)로 막대가 있는 기기를 흉내 낸다.
  - 동선 페이지는 지도를 막대 뒤까지 그린다. 그 대신 제목 카드·일차 칩·버튼과 네이버 로고(가리면 안 됨)는 시스템 여백만큼 띄운다.
  - 지도 여백에는 위에 띄운 요소의 높이를 재서(`SizeReporter`) 넣는다. 그래서 지도는 첫 프레임 다음에 뜬다. 지도를 만들 때부터 여백이 맞아야 처음 카메라가 제목 카드 밑으로 숨지 않는다.
- Dart 패키지 이름은 `mapmarker_app`이다(`pubspec.yaml`, `package:mapmarker_app/...`).
- 줄바꿈이 파일마다 다르다.
  - `flutter create`가 만든 파일(`pubspec.yaml`, `analysis_options.yaml`, `README.md`, Android·iOS 설정 대부분)은 CRLF, `lib/`·`test/`와 문서는 LF, `.gitignore`는 섞여 있다.
  - `.gitattributes`가 없어서 편집기나 스크립트가 줄바꿈을 바꾸면 diff 전체가 바뀐다. 커밋 전에 `git diff --stat`을 확인한다.
- **위젯 테스트**(공용 도우미는 `test/helpers/test_app.dart`)
  - 앱 로캘이 한국어라 `tester.pageBack()`이 'Back' 툴팁을 찾지 못한다. `find.byType(BackButton)`을 누른다.
  - 테스트 화면(800×600)이 작아서 아래쪽 버튼은 `ensureVisible`과 `pumpAndSettle`을 거친 뒤 누른다.
  - 테스트 안에서 저장소 스트림을 `await ...first`로 기다리면 끝나지 않는다(가짜 시간 안의 microtask). 저장된 값은 화면이나 `container.read`로 확인한다.
  - 화면은 `testMaterialApp`으로 띄운다. 앱 테마와 다국어 delegate가 없으면 `context.appColors`와 `context.l10n`이 실패한다.
  - 테스트는 글꼴을 불러오지 않아 글자 폭이 실기기와 다르다. 카드 안 글자 넘침은 실기기에서 본다.
  - `pumpTestApp`은 지도를 가짜 지도(`test/helpers/fake_map.dart`)로 바꿔 끼운다. 지도에 넘긴 마커·선·카메라·여백은 `mapScene(tester)`로 확인한다.
  - 칩은 글자를 누르면 hit test 경고가 난다(글자가 칩의 hit test 경로에 없다). `ChoiceChip`·`FilterChip` 위젯을 찾아 누른다.
- **네이버 SDK 오버레이**
  - 경로선(`NPathOverlay`)은 서로 다른 점이 2개 이상이어야 한다. 같은 자리를 잇는 구간(같은 숙소를 다음 날 첫 장소로 또 넣은 경우)은 그리지 않는다.
  - SDK는 오버레이를 메시지로 바꿔 네이티브 지도에 보낸다. 바꿀 수 없는 값이 하나라도 있으면 같이 보낸 오버레이가 모두 빠지고, 화면에는 아무것도 안 보인다. 오류는 로그(`adb logcat`의 `E flutter`)에만 남는다.
  - 좌표 목록은 꼭 `List`로 넘긴다. `map()`으로 만든 `Iterable`은 메시지로 바뀌지 않는다.
  - `test/core/map/naver/naver_map_provider_test.dart`가 앱이 만든 오버레이와 카메라 요청을 메시지로 바꿔 본다. SDK 오버레이를 새로 쓰면 여기에 추가한다.
  - 카메라 맞춤은 네이버 `fitBounds`가 지도 여백(`contentPadding`)을 빼고 맞추는 것에 기댄다. 지도 위에 띄운 요소를 바꾸면 `MapScene.padding`도 같이 맞춘다.
- 글꼴 라이선스는 `main.dart`에서 라이선스 화면에 등록해 두었다. 설정 화면(`/settings`)을 만들 때 `showLicensePage`로 열 수 있게 한다.
  - 위젯 없이 날짜 표기를 테스트할 때는 `initializeDateFormatting('ko')`를 먼저 부른다. 앱에서는 Material 다국어가 대신 불러 준다.
- 영어를 넣을 때 iOS는 `ios/Runner/Info.plist`에 `CFBundleLocalizations`(ko, en)를 추가해야 한다. 그래야 iOS가 앱의 지원 언어를 안다.
- Flutter를 올리면 마이그레이터가 프로젝트 파일을 자동으로 고친다. 3.47로 올릴 때는 `android/gradle.properties`(AGP 9 호환 설정, 이때 줄바꿈도 LF로 바뀌어 되돌렸다)와 `analysis_options.yaml`(`analyzer: exclude:`)이 바뀌었다. 둘 다 3.47 새 프로젝트 템플릿과 같은 내용이다.
- `android/gradle.properties`의 `android.newDsl=false`, `android.builtInKotlin=false`는 예전 Gradle 설정(`kotlinOptions`, `kotlin-android`)을 쓰는 플러그인(`flutter_naver_map` 등)과 호환하려는 것이다. 플러그인들이 새 방식으로 바뀌기 전에는 지우지 않는다.
- 빌드할 때 "`flutter_naver_map`이 Kotlin Gradle Plugin을 직접 적용한다, 나중 Flutter 버전에서는 빌드가 실패한다"는 경고가 나온다. 지금은 빌드된다. Flutter를 올리기 전에 `flutter_naver_map`이 Built-in Kotlin을 지원하는 버전을 냈는지 확인한다(2025-12에 나온 1.4.4가 최신이다).
- 사진은 Android 사진 선택기로 고른다.
  - 시스템 사진 선택기가 없는 기기(주로 Android 10 이하)는 Google Play 서비스의 사진 선택기 모듈로 열린다. 이 모듈도 없으면 파일 앱으로 넘어가서 다시 한 장만 선택된다.
  - 앱 설치 때 모듈을 받게 하는 `AndroidManifest.xml` 항목(`ModuleDependencies`)을 넣을지는 1-3단계(사진)에서 정한다.
- `gradlew`를 직접 돌릴 때 JAVA_HOME이 없으면 실패한다. Android Studio의 `jbr` 폴더를 JAVA_HOME으로 지정한다. `flutter run`과 `flutter build`는 그대로 된다.

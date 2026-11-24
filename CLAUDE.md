@../.github/CLAUDE.md

# mapmarker-app

MapMarker의 Flutter 앱(Dart SDK ^3.12.0). 소스는 `lib/`, 테스트는 `test/`. 원격은 `mapmarker-dev/mapmarker-app`.

## 명령어

- `flutter pub get`(다국어 코드도 만든다), `flutter analyze`, `flutter test`
- 실행: `flutter run --dart-define-from-file=.env`(VS Code는 `.vscode/launch.json`)
- 실기기로 서버까지 볼 때
  1. 서버: `../mapmarker-server`에서 `npm run db:up` → `npm run start:dev`(서버 `.env`의 `KAKAO_NATIVE_APP_KEY`가 실제 키여야 카카오 로그인이 된다).
  2. 같은 Wi-Fi면 앱 `.env`의 `API_BASE_URL=http://<PC의 Wi-Fi IP>:3000`(`/v1`은 코드가 붙인다). 닿지 않으면 Windows 방화벽에서 3000번 인바운드를 허용한다.
  3. 공용 Wi-Fi에서는 USB로 연결해 `adb reverse tcp:3000 tcp:3000` 뒤 `API_BASE_URL=http://127.0.0.1:3000`.
  4. `flutter run --dart-define-from-file=.env`. debug 빌드만 `http://`를 허용한다(`src/debug/AndroidManifest.xml`).
  - 가입부터 다시 보려면 서버 폴더 `npx prisma studio`에서 `users` 행을 지운다(동의 화면까지 보려면 카카오·네이버 "연결된 서비스 관리"에서도 끊는다). 지운 제주 샘플은 앱 데이터를 지우면 다시 보인다.
- `gradlew`를 직접 돌릴 때는 JAVA_HOME을 Android Studio의 `jbr`로 지정한다.

## 환경 변수

- 키는 `.env`(커밋하지 않음), 목록은 `.env.example`. 새 키를 더하면 `.env.example`도 고친다.
- 앱 코드는 `lib/config/env.dart`의 `Env`로만 읽는다. 필수 값이 비면 `MissingEnvScreen`이 빈 이름을 보여 준다.
- 비밀값(Client Secret 등)은 앱 코드에서 읽지 않는다(빌드에서 누구나 꺼낼 수 있다).
- `.env`(dart-define으로 Dart까지 간다): `NAVER_MAP_CLIENT_ID`, `API_BASE_URL`, `KAKAO_NATIVE_APP_KEY`(Gradle도 읽어 스킴 `kakao<키>`를 만든다).
- `android/local.properties`(커밋하지 않음, Gradle만): `naver.client_id`, `naver.client_secret`, `naver.client_name`. `build.gradle.kts`가 매니페스트 meta-data로 넣고, 없으면 그 로그인만 실패한다.
- **예외: 네이버 로그인 Client Secret은 APK에 들어간다**(OVERVIEW "로그인과 계정"). Dart와 `.env`에는 두지 않고 매니페스트로만 넣는다. `com.naver.sdk.logEnabled`는 `false`(켜면 logcat에 남는다). `naver_login_flutter`는 4.1.0에 고정했고 올릴 때 로그 출력을 다시 본다. 플러그인의 `configure` CLI는 쓰지 않는다(Secret이 셸 기록에 남는다).
- 카카오 콘솔에는 개발 PC의 debug 키 해시만 있다. 다른 PC에서 빌드하면 그 키 해시를 더한다.

## 브랜치

`main`(기본), `dev`(개발), `test`(기술 검증) 3개만 쓴다.

## 폴더 구조

```
lib/
├─ main.dart        SDK 초기화 → ProviderScope → MapMarkerApp
├─ app/             MaterialApp, 경로 표(router.dart), 경로 상수(routes.dart)
├─ config/          환경 변수(Env)
├─ data/            모델, 저장소, 서버 API. 여러 기능이 함께 쓴다
├─ core/            기능에 속하지 않는 공용 코드(디자인 토큰·테마, 곡선 계산, 지도 인터페이스, 동선 그림, 이미지 저장과 공유 등)
├─ features/<기능>/  화면과 상태(Riverpod). 예: login, trips, trip_detail, trash, export
└─ l10n/            다국어 글자(app_ko.arb)와 모델 글자 변환
```

- 폴더는 파일이 생길 때 만들고, `test/`는 `lib/`와 같은 구조다. 기능 폴더는 `xxx_screen.dart`, `xxx_controller.dart`(Notifier), `widgets/`로 시작한다.
- 기능끼리는 서로 import하지 않는다. 같이 쓸 코드는 `data/`나 `core/`로 옮긴다.
- 화면은 경로로 이동한다(`context.go(Routes.xxx)`). 새 화면은 `app/router.dart`의 여행 목록(`/`) 아래에 둔다(딥링크로 열어도 뒤로가기가 목록으로 가게).
  - 예외: 로그인(`/login`)은 최상위다(목록 아래면 토큰 없이 목록이 만들어지고 뒤로가기가 앱을 닫지 못한다). 로그인 여부에 따른 이동은 `authRedirect` 한 곳(가려던 곳은 `?from=`, 앱 안 경로만).
- 서버 API는 `data/api/ApiClient`(토큰 붙이기·재발급)로만 부른다. 여행 저장소는 로그인한 사용자마다 `ServerTripRepository`를 만들어 `SampleTripRepository`로 감싼다(`tripRepositoryProvider`). 쓰기 실패는 `ApiException`이고 화면은 `saveFailureText`로 알린다. 주소 검색·좌표는 `data/addresses/AddressApi`, 실패 안내는 `searchFailureText`. 사진은 `data/photos/`(아래 "사진").
- 상태 관리는 Riverpod을 코드 생성 없이 쓴다.

## 다국어

- 화면 글자는 `lib/l10n/app_ko.arb`에 두고 `context.l10n`(컨트롤러는 `l10nProvider`)으로 읽는다. 모델(`data/`)에는 글자를 두지 않는다.
- 문장은 조각을 이어 붙이지 않고 자리 표시자가 있는 문장 하나로 둔다(언어마다 어순이 다르다).
- 화면 글자에 가운뎃점(·)을 쓰지 않는다. `test/l10n/arb_style_test.dart`가 검사한다.
- 개발자만 보는 글자(오류·로그, 디버그 화면)는 옮기지 않는다.

## 디자인

- 색·여백·모서리는 `lib/core/theme/` 토큰으로 읽는다: 색은 `colorScheme`이나 `context.appColors`, 여백 `AppSpace`, 모서리 `AppRadius`. `colorScheme`에 없는 색은 `AppColors`에 이름을 붙여 더한다(다크 모드 때 값만 바꾸려고).
- 컴포넌트 테마에 글자 모양을 넣을 때는 `app_theme.dart`의 크기를 붙인 글자(`typography.dense`를 합친 것)를 쓴다. `ThemeData.textTheme`에는 크기가 없어 그대로 넣으면 기본 14로 그려진다. 입력 칸 모양(밑줄형)도 테마가 정하니 화면에서 테두리를 주지 않는다.
- 스크롤 여백을 직접 정하면 `MediaQuery.paddingOf(context)`를 더하고, 화면 전체를 `SafeArea`로 감싸지 않는다(Android 15 이상은 화면 끝까지 그린다).
- 글꼴 파일(`assets/fonts/`)은 원본 그대로 둔다(고치면 OFL 예약 이름 때문에 이름을 바꿔야 한다).

## 사진

- 장소마다 1장. 사진 칸(`PlacePhotoField`)에서 고르면 원본으로 줄이고(`PhotoPreparer.shrink`: 긴 변 1920px, EXIF 지움), "사진 위치" 화면에서 고른 정사각형으로 썸네일(400×400)을 만든다. 마커, 장소 줄, 내보내기는 썸네일을 쓴다. 썸네일 자르기는 Flutter로 그린 PNG를 플러그인으로 JPEG로 바꾼다.
- **위치 정보:** `image_picker`의 줄이기는 쓰지 않는다(Android에서 GPS를 새 파일로 옮긴다). `flutter_image_compress`(`keepExif: false`)로 다시 쓰고, 올리기 전에 `hasMetadataSegment`로 APP1(EXIF, XMP)이 없는지 한 번 더 본다. 플러그인은 짧은 변 기준이라 `shortSideFor`로 값을 넘긴다.
- 올리기: [저장]할 때 장소를 먼저 저장하고 `ServerTripRepository.setStopPhoto`(업로드 주소 → S3 PUT → 등록). S3는 따로 된 dio(`photoDioProvider`)로만 부른다(서버 토큰이 S3로 가면 안 된다). 사진만 실패하면 `PhotoSaveException`이고, 다시 저장하면 사진만 보낸다.
- 보기: 주소는 응답마다 새로 서명되므로 이미지(`PhotoImage`)는 사진 ID와 크기로 기억한다. 403(만료)이면 보고 있는 여행을 다시 받는다(30초에 한 번).
- 사진 마커(`MarkerLook.photo`): `NOverlayImage.fromWidget`이 이미지를 기다리지 않아서 `precacheImage`로 먼저 받고, 못 받으면 원 마커로 그린다.
- **사진 방향**(`Stop.photoSide`, 기본 위): 사진 마커의 모양과 기준점은 `MarkerIcon.sizeOf`·`anchorOf`가 방향마다 정한다(꼬리 끝이 장소, 번호 원은 장소에서 먼 쪽 모서리, 이름은 사진 반대쪽 `naverCaptionAlignOf`). 합친 마커는 사진을 주는 장소(`photoStopAt`)의 방향이다.
  - 바꾸기: 일차 보기에서 사진 있는 장소 줄을 펼치면 `MapScene.photoSidePicker`(화살표 4개, 그림은 네이버 마커 하나, 누르는 영역은 곡선 핸들처럼 카메라가 멈추면 Flutter로 놓는다) → `onPhotoSideChanged` → `updateStop`. 저장하는 동안 마커는 `MapMarker.pending`(흐림)이고 화살표가 없다. 장소 편집 화면에는 없다(지도를 보며 바꾼다). 방향을 고르면 화살표를 숨기고(`_photoSideDone`), 그 마커를 다시 누르거나 펼친 줄이 바뀌면 다시 띄운다.
  - 앱은 장소를 고칠 때마다 `photoSide`를 보내서 이 칸이 없는 서버에는 400이다. 서버를 먼저 올린다.
- **같은 자리 장소는 사진 하나와 방향 하나를 함께 쓴다**(좌표가 같은 장소: 연박 숙소, 처음과 끝이 같은 공항). 데이터는 그 자리에서 사진이 있는 첫 장소(`TripRoute.photoOwnerOf`)에만 있고, 동선 화면과 내보내기는 `withSharedPhotos`로 모든 밤에 같은 사진과 방향을 그린다.
  - 사진 쓰기는 `TripDetailController.setStopPhoto`/`deleteStopPhoto`가 주인 장소로 보낸다(어느 밤에서 넣어도 주인에, 지우면 그 자리 사진 모두). 이 규칙 전에 따로 넣은 사진은 새로 넣을 때 지워 하나로 맞춘다. 방향 화살표도 주인 장소의 방향을 바꾼다.
  - 주인 장소를 지우거나 후보로 빼면 서버가 사진과 방향을 같은 자리의 다음 장소로 넘긴다(`MemoryTripRepository`도 같다). 그래서 지우기 확인의 "사진도 사라진다"는 그 자리의 마지막 장소일 때만이다.
- `AndroidManifest.xml`의 `ModuleDependencies` 서비스는 시스템 사진 선택기가 없는 기기에 Google Play 서비스가 선택기를 받게 한다.

## 여행 중 (현재 위치, 방문)

규칙과 이유는 OVERVIEW "여행 중". 코드 위치와 지킬 것만 적는다.

- **현재 위치**는 `core/location/LocationSource`(`locationSourceProvider`)로만 받는다. geolocator의 `GeolocatorLocationService`는 매니페스트에 남겨 둔다(위치 스트림이 이 서비스에 붙는다). 포그라운드 알림 설정과 `FOREGROUND_SERVICE_LOCATION` 권한은 쓰지 않는다.
  - 지도에는 `MapScene.myLocation`으로 넘기고 네이버 구현은 SDK의 위치 오버레이를 쓴다. 파랑(`AppColors.myLocation`)은 현재 위치에만 쓴다.
- **방문**은 `updateStop`의 `visitedAt`으로 저장한다(확인 창 `VisitDialog`, 기록 시각 규칙과 날짜 범위는 `stop_visit.dart`). 방문 시각은 장소의 `timeZone`으로 보여 준다(`core/time/zoned_time.dart`). 기기 시간대를 쓰지 않는다.
- 오늘 일차로 열기는 `RouteChoiceController.build`, 그날 밤 숙소 버튼은 `DayItinerary.lodgingsToStayAgain`, 칩 접기는 `routeChipsCollapsedProvider`(`RouteChipsStore`로 기기에 기억)다.

## 지도 (네이버 SDK)

- `flutter_naver_map`은 `core/map/naver/`와 `main.dart`에서만 쓰고, 나머지는 `MapProvider`만 본다.
- SDK는 오버레이를 메시지로 바꿔 보낸다. 바꿀 수 없는 값이 하나라도 있으면 같이 보낸 오버레이가 모두 빠지고 오류는 `adb logcat`의 `E flutter`에만 남는다. 좌표·무늬는 `List`로 넘긴다(`map()`의 `Iterable`은 안 된다). 새 오버레이를 쓰면 `test/core/map/naver/naver_map_provider_test.dart`에 변환 테스트를 더한다.
- 리스너를 단 오버레이는 탭을 먹어 지도 탭이 불리지 않는다. 카메라 맞춤은 `fitBounds`가 지도 여백을 빼는 것에 기대므로, 지도 위 요소를 바꾸면 `MapScene.padding`도 맞춘다.
- 네이버 로고는 끄거나 가리지 않는다(내보내기 이미지 포함).

## 이미지 내보내기

규칙과 이유는 OVERVIEW "사진, 이미지, 공유". 코드 위치와 지킬 것만 적는다.

- 흐름: `MapProvider.buildCaptureMap`이 결과 크기(1080×1350px ÷ 기기 픽셀 비율)의 지도를 오버레이 없이 찍고(`MapCapture`), `features/export/`의 `ExportCanvas`가 그 위에 동선을 위젯으로 그린다. 미리보기가 곧 결과이고, 저장할 때 `RepaintBoundary.toImage`로 PNG를 만든다. 지도는 미리보기 뒤에 가려 둔다(가려져도 찍힌다).
- 동선 모양은 앱 지도와 같은 `core/route/route_scene.dart`의 `routeOverlays`에서 나온다. 이미지에 넣을 것은 `buildExportScene`, 자리 잡기(이름표 겹침, 짧은 선의 화살표 숨김)는 `layoutExport`다.
- 동선의 순서와 장소가 먼저다. 방문 여부나 사진 때문에 어떤 장소나 구간도 흐리게 그리거나 가리지 않는다(사진 마커는 번호 마커 아래에 그린다).
- 제목 카드 높이와 마커가 솟는 높이만큼 지도 위쪽 여백을 두고 맞춰서(`ExportScene.frameFor`, `MapFrame.fit`) 장소가 카드에 가리지 않는다. 범위, 숙소, 제목, 사진을 바꾸면 여백이나 범위가 바뀌어 지도를 다시 찍는다.
- 미리보기를 끌고 늘리면 그동안은 보이는 그림만 `Transform`으로 밀고 키우고(저장하는 `RepaintBoundary` 바깥), 손을 떼면 `MapFrame.at`(가운데, 줌)으로 다시 찍는다. 줌은 `MapCapture.zoom` + log2(배율)이다. 다시 찍기 전에는 저장할 수 없다(보이는 것과 저장할 것이 다르다).
- 지도 로고 자리(`MapCapture.logo`)는 다 그린 뒤 찍은 지도로 다시 덮는다. 이미지 글자는 기기 글자 크기 설정을 따르지 않는다.
- 저장과 공유는 `core/share/ImageSharing`(gal, share_plus, PNG를 JPEG 92로)만 부른다. Android 10 이하는 저장 권한(`WRITE_EXTERNAL_STORAGE`, maxSdk 29)을 묻고, 10은 앨범에 넣으려고 `requestLegacyExternalStorage`도 켠다.

## 테스트

- 실제 서버·카카오·네이버에 붙지 않는다. HTTP는 `FakeHttp`를 끼운 dio, 로그인은 `authOverrides`·`testSession`·`FakeSocialSdk`, 저장 실패와 기다림은 `FlakyTripRepository`(`failWrites`·`holdWrites`), 샘플은 `withSample`·`MemorySampleStore`, 칩 접기는 `MemoryRouteChipsStore`(`pumpTestApp(routeChipsStore:)`, 기본은 펼침), 주소 검색은 `FakeAddressApi`(`pumpTestApp(addressApi:)`).
- 기기 위치는 `FakeLocationSource`(`pumpTestApp(locationSource:)`, 기본은 권한 없음): `granted`·`answer`·`serviceOff`로 권한을 정하고 `emit`으로 위치를 낸다. 낸 위치는 `pump` 두 번 뒤에 그려진다. 시각을 확인할 때는 기기 시간대와 상관없게 `zonedParts`로 서울 시각을 계산한다.
- 사진은 `FakePhotoSource`·`FakePhotoPreparer`(원본 400×300, 고른 정사각형은 `areas`)와 1×1 그림을 주는 `fakePhotoImages`, 사진만 실패는 `FlakyTripRepository.failPhotos`. 사진을 고르면 "사진 위치" 화면에서 [확인]을 눌러야 하고, 사진 칸은 `scrollUntilVisible`로 내린다.
- 내보내기는 가짜 지도가 다음 프레임에 1×1 그림을 찍은 것으로 넘기고(`fakeCapture`, 실패는 `pumpTestApp(mapCaptureFails:)`), 저장과 공유는 `FakeImageSharing`(`pumpTestApp(imageSharing:)`)이 받는다. 저장과 공유는 이미지를 실제로 만들어서 `runAsync`와 `pump`를 번갈아 기다린다. 사진 마커가 있으면 사진을 받는 것도 실제 시간이 걸린다.
- 지도의 사진 방향 화살표는 `pickPhotoSide(tester, side)`로 누른다(`MapScene.photoSidePicker`가 있어야 한다).
- 공용 도우미는 `test/helpers/`. 화면은 `pumpTestApp`(가짜 지도, 기본 로그인)이나 `testMaterialApp`, 지도에 넘긴 장면은 `mapScene(tester)`, 지도 탭은 `tapMarker`·`tapLine`·`tapMap`.
- 기본 화면(800×600)은 가로라 동선 목록이 오른쪽 패널이다. 아래 시트는 `usePortraitPhone`. 연필은 줄을 먼저 눌러야 뜨고, 순서 손잡이는 제목 줄의 [순서 바꾸기]를 눌러야 뜬다.
- 로캘이 한국어라 `tester.pageBack()` 대신 `find.byType(BackButton)`을 누른다. 칩은 `ChoiceChip`·`FilterChip` 위젯을 누른다.
- 저장소 스트림을 `await ...first`로 기다리지 않는다(가짜 시간 안에서 멈춘다). 꼭 기다리면 `tester.runAsync` 안에서. 진행 표시가 도는 동안은 `pumpAndSettle` 대신 `pump`를 여러 번.
- `enterText` 뒤에는 `pump` 한 번. 위젯 없이 날짜 표기를 볼 때는 `initializeDateFormatting('ko')`를 먼저.
- 테스트는 글꼴을 불러오지 않아 글자 폭이 다르다. 글자 넘침은 실기기에서 본다.

## 의존성과 프로젝트 파일

- **go_router는 17.x에 묶는다.** 18은 Material을 `material_ui`로 옮겨 이 앱의 모든 화면이 전환 애니메이션 없이 뜬다. Flutter 템플릿과 `flutter_naver_map`이 옮긴 뒤 함께 올린다(그때 `test/app/router_test.dart`가 실패한다).
- `android/gradle.properties`의 `android.newDsl=false`, `android.builtInKotlin=false`는 예전 Gradle 설정을 쓰는 플러그인 호환용이다. 플러그인이 바뀌기 전에는 지우지 않는다.
- Flutter를 올리면 마이그레이터가 고친 프로젝트 파일이 템플릿과 같은지 보고, 줄바꿈이 바뀌었으면 되돌린다.
- 플랫폼 폴더는 Android·iOS만 둔다(지도 SDK가 두 플랫폼만 지원). 다른 플랫폼 폴더가 남아 있으면 지운다.
- 줄바꿈이 파일마다 다르다. `flutter create`가 만든 파일(`pubspec.yaml`, `analysis_options.yaml`, `README.md`, Android·iOS 설정 대부분)은 CRLF, `lib/`·`test/`와 문서는 LF다. `.gitattributes`가 없어 커밋 전에 `git diff --stat`을 본다.

## 코딩 규칙

- `flutter_lints`를 따르고 커밋 전에 `flutter analyze`와 `flutter test`가 통과하는지 본다.
- iOS를 지원하지 않는 패키지는 쓰지 않는다.

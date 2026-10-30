@../.github/CLAUDE.md

# mapmarker-app

MapMarker의 Flutter 앱 (Dart SDK ^3.12.0). 소스는 `lib/`, 테스트는 `test/`. 원격 저장소는 `mapmarker-dev/mapmarker-app`.

## 명령어

- 의존성 설치: `flutter pub get` (다국어 코드도 이때 만든다)
- 정적 분석: `flutter analyze`
- 테스트: `flutter test`
- 실행: `flutter run --dart-define-from-file=.env` (VS Code는 `.vscode/launch.json`에 설정돼 있음)
- `gradlew`를 직접 돌릴 때는 JAVA_HOME을 Android Studio의 `jbr` 폴더로 지정한다(`flutter run`·`flutter build`는 그대로 된다).

## 환경 변수

- 키는 `.env`에 둔다. `.env`는 커밋하지 않고, 항목 목록은 `.env.example`에 둔다. 새 키를 추가하면 `.env.example`도 함께 고친다.
- 앱 코드는 `lib/config/env.dart`의 `Env`로만 값을 읽는다.
- Client Secret 같은 비밀값은 앱 코드에서 읽지 않는다. 앱 빌드에 들어가면 누구나 꺼낼 수 있다.

## 브랜치

이 저장소는 브랜치를 아래 4개만 운영한다. 다른 브랜치를 새로 만들지 않는다.

- `main`: 기본 브랜치
- `dev`: 개발할 때
- `test`: 기술 검증 같은 테스트가 필요할 때
- `wip/<브랜치>` : 공통 규칙의 인수인계용 임시 브랜치

## 폴더 구조

```
lib/
├─ main.dart        SDK 초기화 → ProviderScope → MapMarkerApp
├─ app/             MaterialApp, 경로 표(router.dart), 경로 상수(routes.dart)
├─ config/          환경 변수(Env)
├─ data/            모델, 저장소, 서버 API. 여러 기능이 함께 쓴다
├─ core/            기능에 속하지 않는 공용 코드 (디자인 토큰·테마, 곡선 계산, 지도 인터페이스 등)
├─ features/<기능>/  화면과 상태(Riverpod). 예: trips, trip_detail, export
├─ l10n/            다국어 글자(app_ko.arb)와 모델 글자 변환
└─ dev/             개발용 화면. 경로는 디버그 빌드에서만 등록한다
```

- 폴더는 파일이 생길 때 만든다. `test/`는 `lib/`와 같은 구조로 둔다.
- 기능 폴더는 `xxx_screen.dart`, `xxx_controller.dart`(Notifier), `widgets/`로 시작하고, 파일이 많아지면 나눈다.
- 기능끼리는 서로 import하지 않는다. 같이 쓸 코드는 `data/`나 `core/`로 옮긴다.
- 화면은 경로로 이동한다(`context.go(Routes.xxx)`). 새 화면은 `app/router.dart`의 여행 목록(`/`) 아래에 등록한다. 딥링크로 바로 열어도 뒤로가기가 여행 목록으로 가게 하기 위해서다.
- 상태 관리는 Riverpod을 코드 생성 없이 쓴다.

## 다국어

- 화면 글자는 `lib/l10n/app_ko.arb`에 두고 `context.l10n`(컨트롤러는 `l10nProvider`)으로 읽는다. 모델(`data/`)에는 글자를 두지 않는다.
- 문장은 조각을 이어 붙이지 않고 자리 표시자가 있는 문장 하나로 둔다. 언어마다 어순이 다르기 때문이다.
- 개발자만 보는 글자(오류·로그, 디버그 전용 화면)는 옮기지 않는다.

## 디자인

- 색·여백·모서리는 값을 직접 쓰지 않고 `lib/core/theme/`의 토큰으로 읽는다. 색은 `colorScheme`이나 `context.appColors`, 여백은 `AppSpace`, 모서리는 `AppRadius`다.
- `colorScheme`에 없는 색이 필요하면 `AppColors`에 이름을 붙여 추가한다. 다크 모드 때 값만 바꾸기 위해서다.
- 스크롤 여백을 직접 정하면 `MediaQuery.paddingOf(context)`를 더한다. 화면 전체를 `SafeArea`로 감싸지는 않는다. 내용은 시스템 막대 뒤로 지나가되 끝까지 보이게 하기 위해서다(Android 15 이상은 화면 끝까지 그린다).
- 글꼴 파일(`assets/fonts/`)은 원본 그대로 둔다. 고치면 OFL 예약 이름 때문에 글꼴 이름을 바꿔야 한다.

## 지도 (네이버 SDK)

- `flutter_naver_map`은 `core/map/naver/`, `main.dart`(SDK 초기화), `dev/snapshot_lab/`에서만 쓴다. 나머지 코드는 `MapProvider`만 본다.
- SDK는 오버레이를 메시지로 바꿔 네이티브 지도에 보낸다. 바꿀 수 없는 값이 하나라도 있으면 같이 보낸 오버레이가 모두 빠지고, 오류는 `adb logcat`의 `E flutter`에만 남는다. 좌표·무늬는 `List`로 넘긴다(`map()`의 `Iterable`은 안 된다). 새 오버레이를 쓰면 `test/core/map/naver/naver_map_provider_test.dart`에 메시지 변환 테스트를 더한다.
- 리스너를 단 오버레이는 탭을 먹어 지도 탭이 불리지 않는다. 카메라 맞춤은 `fitBounds`가 지도 여백을 빼고 맞추는 것에 기대므로, 지도 위에 띄운 요소를 바꾸면 `MapScene.padding`도 맞춘다.
- 네이버 로고는 끄거나 가리지 않는다(내보내기 이미지 포함).

## 테스트

- 공용 도우미는 `test/helpers/`다. 화면은 `pumpTestApp`(지도를 가짜 지도로 바꿔 끼움)이나 `testMaterialApp`으로 띄운다. 지도에 넘긴 장면은 `mapScene(tester)`, 지도 탭은 `tapMarker`·`tapLine`·`tapMap`으로 본다.
- 기본 화면(800×600)은 가로라 동선 목록이 오른쪽 패널로 뜬다. 아래 시트는 `usePortraitPhone`으로 띄운다. 연필·손잡이는 줄을 먼저 눌러야 뜬다.
- 앱 로캘이 한국어라 `tester.pageBack()` 대신 `find.byType(BackButton)`을 누른다. 칩은 글자 대신 `ChoiceChip`·`FilterChip` 위젯을 누른다.
- 저장소 스트림을 `await ...first`로 기다리지 않는다(가짜 시간 안에서 끝나지 않는다). 저장된 값은 화면이나 `container.read`로 본다.
- `enterText` 뒤에는 `pump`를 한 번 한다. 위젯 없이 날짜 표기를 볼 때는 `initializeDateFormatting('ko')`를 먼저 부른다.
- 테스트는 글꼴을 불러오지 않아 글자 폭이 실기기와 다르다. 글자 넘침은 실기기에서 본다.

## 의존성과 프로젝트 파일

- **go_router는 17.x에 묶는다.** 18은 Material을 `material_ui` 패키지로 옮겨서, `flutter/material`의 `MaterialApp`을 쓰는 이 앱은 모든 화면이 전환 애니메이션 없이 뜬다. Flutter 템플릿과 `flutter_naver_map`이 `material_ui`로 옮긴 뒤 앱 import와 함께 올린다(그때 `test/app/router_test.dart`의 Material 페이지 테스트가 실패한다).
- `android/gradle.properties`의 `android.newDsl=false`, `android.builtInKotlin=false`는 예전 Gradle 설정을 쓰는 플러그인(`flutter_naver_map` 등)과 호환하려는 것이다. 플러그인들이 바뀌기 전에는 지우지 않는다.
- Flutter를 올리면 마이그레이터가 프로젝트 파일을 고친다. 새 프로젝트 템플릿과 같은 내용인지 보고, 줄바꿈이 바뀌었으면 되돌린다.
- 플랫폼 폴더는 Android·iOS만 둔다(네이버 지도 SDK가 두 플랫폼만 지원). 다른 플랫폼 폴더가 로컬에 남아 있으면 `flutter pub get` 때 플러그인 등록 파일이 다시 생기니 지운다.
- 줄바꿈이 파일마다 다르다. `flutter create`가 만든 파일(`pubspec.yaml`, `analysis_options.yaml`, `README.md`, Android·iOS 설정 대부분)은 CRLF, `lib/`·`test/`와 문서는 LF다. `.gitattributes`가 없어서 줄바꿈이 바뀌면 diff 전체가 바뀌니, 커밋 전에 `git diff --stat`을 본다.

## 코딩 규칙

- `flutter_lints` 규칙(`analysis_options.yaml`)을 따른다.
- 커밋 전에 `flutter analyze`와 `flutter test`가 통과하는지 확인한다.
- iOS를 지원하지 않는 패키지는 쓰지 않는다 (iOS는 MVP 이후 출시 예정).

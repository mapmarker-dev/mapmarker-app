# HANDOFF

> 최종 갱신: 2026-10-16 · 브랜치: dev

## 지금 하는 일

다국어 구조(gen-l10n)를 마쳤다. 화면 글자와 모델 글자를 `lib/l10n/`로 옮겼고, 화면은 바뀌지 않았다. 지금은 디자인 토큰 단위를 제안하고 확인을 기다리는 중이다. 사용자가 정한 순서는 다국어 구조 → 디자인 토큰 → 여행 동선 페이지다.

## 다음에 할 첫 단계

1. 디자인 토큰 단위. 제안을 확인받은 뒤 구현한다. 확인받을 것은 아래 "결론이 안 난 논의"에 있다.
2. 여행 동선 페이지와 `MapProvider`(네이버). `/trips/:tripId` 화면에 지도를 넣고, Stop·Segment용 저장소 메서드는 이때 추가한다.
3. 그다음 순서 후보: 장소 편집·상세 시트 → 구간·이동 수단·화살표 → 곡선 핸들 → 서버 연동·로그인.

## 현재 상태

- `flutter analyze` 문제 0건, `flutter test` 92개 통과.
- 실기기(갤럭시 탭, 갤럭시 휴대폰)에서 다국어 구조까지 확인했다.
- 디버그 빌드는 시작할 때 샘플 여행 3개를 넣는다(`lib/dev/sample_trips.dart`, `main.dart`). 오늘 기준 제주(중), 강릉(전, 날짜 미정), 부산(후)이다. 테스트는 빈 저장소로 시작한다.
- `dev`는 `origin/dev`보다 커밋 2개 앞서 있다(여행 기본, 다국어 구조. push 전).

## 아직 문서에 없는 결정

- **화면 동작**
  - 여행 목록은 최근에 만들거나 고친 순서다. 상태를 바꿔도 위로 올라간다(채팅 앱 목록처럼).
  - 상태 변경 UI는 목록의 상태 칩 메뉴에만 있다. 여행 화면은 다음 단위에 지도가 들어올 자리라서 두지 않았다.
  - 제목 바꾸기는 여행 화면 앱 바의 연필 버튼이다. 칸을 비우면 기본 제목으로 돌아간다.
- **여행 만들기**
  - 기간이 있으면 일정은 고정되고, 계절은 시작일 기준으로 자동 선택되지만 바꿀 수 있다(11월 말처럼 경계에 걸린 달 때문).
  - 기간이 없으면 일정은 −/+ 버튼으로 고른다(기본 1박 2일, 당일치기~30박). 계절은 기본값 없이 꼭 고르게 했다. 틀린 계절이 제목에 들어가지 않게 하려는 것이다.
  - 날짜는 과거 10년부터 앞으로 5년까지 고를 수 있다. 지난 여행도 기록할 수 있게 하려는 것이다.
- **저장소:** `TripRepository`는 `watchTrips`·`watchTrip` 스트림과 `createTrip`·`updateTrip`이다. 화면끼리 서로 갱신을 알리지 않아도 되게 하려는 것이다. 서버 구현은 받아 온 여행을 기억해 두고, 이 앱에서 바꾼 내용을 반영해 다시 내보내야 한다. 이 부분은 2-2단계 오프라인 보기와 함께 설계한다.
- 서버가 생기기 전에는 디버그 빌드에서만 샘플 여행을 넣는다. 메모리 저장소는 앱을 끄면 비기 때문이다.
- 앱 언어는 `appLocale`(ko)로 고정했다(`lib/l10n/l10n.dart`).
  - 영어를 넣을 때 기기 언어를 따를지 정한다.
  - 그때 `MaterialApp`의 `locale`과 컨트롤러가 쓰는 `l10nProvider`가 같은 언어를 쓰게 맞춘다.
- 구간의 이동 수단은 고르지 않아도 된다. 비어 있으면 "미정"이다.
- 걸리는 시간은 "3시간 20분"처럼 적는다.
- 앱에는 Android·iOS 폴더만 남겼다(`linux/`, `macos/`, `windows/`, `web/`는 지웠다). 네이버 지도 SDK가 두 플랫폼만 지원하기 때문이다. 이 폴더들이 로컬에 비어서 남아 있으면 `flutter pub get` 때 플러그인 등록 파일이 다시 생기니 지운다.
- 앱 표시 이름은 `MapMarker`다(Android `android:label`, iOS `CFBundleDisplayName`).
- 1단계 경로: `/login`, `/`, `/trips/new`, `/trips/:tripId`(일차 전환은 화면 상태), `/trips/:tripId/export`, `/settings`. 3단계에 `/shared/:shareId`(공유 링크 `/trip/<공유ID>`를 redirect로 연결). 장소 상세는 경로가 아니라 바텀 시트다.
- `MapProvider`는 Riverpod의 Provider와 이름이 겹치지만, 문서에 맞추려고 그대로 둔다. 어느 지도인지 나타내는 enum은 `MapProviderType`이다(여행의 지도와 Stop의 `placeProvider`에 함께 쓴다).
- **go_router는 17.x에 묶어 둔다.**
  - go_router 18은 Material을 새 `material_ui` 패키지로 옮겼다. 그래서 `package:flutter/material.dart`의 `MaterialApp`을 쓰는 앱은 MaterialApp으로 알아보지 못하고, 모든 화면을 전환 애니메이션 없는 `NoTransitionPage`로 띄운다.
  - Flutter 3.47 새 프로젝트 템플릿과 `flutter_naver_map`(로고 위젯 포함)이 아직 `flutter/material`을 쓴다. 그래서 앱도 거기에 맞췄다.
  - 플러그인들이 `material_ui`로 옮기면 앱 import와 함께 18로 올린다. 18로 올리면 `test/app/router_test.dart`의 Material 페이지 테스트가 실패한다.

## 결론이 안 난 논의

- **디자인 토큰 단위에서 확인받을 것.** 정해진 것(3단계 구조, 주 색 코랄, 둥근 글꼴, 라이트 모드 먼저)은 OVERVIEW에 있다. 지금 화면은 Material 3 기본 테마이고, 색은 `colorScheme`의 역할로만 지정해 두었다.
  - **코랄 색 값:** 제안은 #FF6F61을 씨앗 색으로 쓰고 `ColorScheme.fromSeed(dynamicSchemeVariant: fidelity)`로 만드는 것이다.
    - 기본 방식(`tonalSpot`)은 코랄을 갈색(#904A42)으로 바꾼다.
    - `fidelity`는 #FF6F61을 그대로 `primaryContainer`로 쓰고, 그 위 글자는 진한 빨강(#6F0205, 대비 4.56:1)이다.
    - 흰 글자를 코랄 위에 놓으면 대비가 2.73:1이라 글자 기준(4.5:1)에 못 미친다.
  - **글꼴:** 제안은 나눔스퀘어라운드다(굵기 4개, 한글·영문). 나눔 글꼴은 대부분 OFL이지만, 이 글꼴의 라이선스 파일은 공식 배포본에서 직접 확인해야 한다. 구글 폰트의 동글(굵기 3개), 주아(1개), 고운돋움(1개)은 OFL로 확인했다.
  - 태블릿에서도 한 줄에 카드 2개로 할지.
  - 상태 칩의 색. 이동 수단의 색과 선 스타일, "미정" 구간의 선은 구간 단위에서 정한다.
  - 정사각형 카드에 무엇을 넣을지: 제목·기간·상태 말고 동선 미리보기나 사진을 넣을지.
- 영어를 넣는 시점과 언어를 고르는 방식은 아직 정하지 않았다(`PLAN.md` "아직 확인할 것").
- 갈아타는 구간(예: 지하철 2정류장 + 도보)의 아이콘과 선 스타일을 어느 수단으로 그릴지 정해야 한다. 구간·이동 수단 단위에서 정한다.
- 남반구 해외 여행에서는 계절이 반대가 된다. 2단계에서 다시 본다.

## 주의할 점

- Dart 패키지 이름은 `mapmarker_app`이다(`pubspec.yaml`, `package:mapmarker_app/...`).
- 줄바꿈이 파일마다 다르다.
  - `flutter create`가 만든 파일(`pubspec.yaml`, `analysis_options.yaml`, `README.md`, Android·iOS 설정 대부분)은 CRLF, `lib/`·`test/`와 문서는 LF, `.gitignore`는 섞여 있다.
  - `.gitattributes`가 없어서 편집기나 스크립트가 줄바꿈을 바꾸면 diff 전체가 바뀐다. 커밋 전에 `git diff --stat`을 확인한다.
- **위젯 테스트**(공용 도우미는 `test/helpers/test_app.dart`)
  - 앱 로캘이 한국어라 `tester.pageBack()`이 'Back' 툴팁을 찾지 못한다. `find.byType(BackButton)`을 누른다.
  - 테스트 화면(800×600)이 작아서 아래쪽 버튼은 `ensureVisible`과 `pumpAndSettle`을 거친 뒤 누른다.
  - 테스트 안에서 저장소 스트림을 `await ...first`로 기다리면 끝나지 않는다(가짜 시간 안의 microtask). 저장된 값은 화면이나 `container.read`로 확인한다.
  - 화면은 `testMaterialApp`으로 띄운다. 다국어 delegate가 없으면 `context.l10n`이 실패한다.
  - 위젯 없이 날짜 표기를 테스트할 때는 `initializeDateFormatting('ko')`를 먼저 부른다. 앱에서는 Material 다국어가 대신 불러 준다.
- 영어를 넣을 때 iOS는 `ios/Runner/Info.plist`에 `CFBundleLocalizations`(ko, en)를 추가해야 한다. 그래야 iOS가 앱의 지원 언어를 안다.
- Flutter를 올리면 마이그레이터가 프로젝트 파일을 자동으로 고친다. 3.47로 올릴 때는 `android/gradle.properties`(AGP 9 호환 설정, 이때 줄바꿈도 LF로 바뀌어 되돌렸다)와 `analysis_options.yaml`(`analyzer: exclude:`)이 바뀌었다. 둘 다 3.47 새 프로젝트 템플릿과 같은 내용이다.
- `android/gradle.properties`의 `android.newDsl=false`, `android.builtInKotlin=false`는 예전 Gradle 설정(`kotlinOptions`, `kotlin-android`)을 쓰는 플러그인(`flutter_naver_map` 등)과 호환하려는 것이다. 플러그인들이 새 방식으로 바뀌기 전에는 지우지 않는다.
- 빌드할 때 "`flutter_naver_map`이 Kotlin Gradle Plugin을 직접 적용한다, 나중 Flutter 버전에서는 빌드가 실패한다"는 경고가 나온다. 지금은 빌드된다. Flutter를 올리기 전에 `flutter_naver_map`이 Built-in Kotlin을 지원하는 버전을 냈는지 확인한다(2025-12에 나온 1.4.4가 최신이다).
- 사진은 Android 사진 선택기로 고른다.
  - 시스템 사진 선택기가 없는 기기(주로 Android 10 이하)는 Google Play 서비스의 사진 선택기 모듈로 열린다. 이 모듈도 없으면 파일 앱으로 넘어가서 다시 한 장만 선택된다.
  - 앱 설치 때 모듈을 받게 하는 `AndroidManifest.xml` 항목(`ModuleDependencies`)을 넣을지는 1-3단계(사진)에서 정한다.
- `gradlew`를 직접 돌릴 때 JAVA_HOME이 없으면 실패한다. Android Studio의 `jbr` 폴더를 JAVA_HOME으로 지정한다. `flutter run`과 `flutter build`는 그대로 된다.

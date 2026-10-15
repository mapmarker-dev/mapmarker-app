# HANDOFF

> 최종 갱신: 2026-10-15 · 브랜치: dev

## 지금 하는 일

앱 뼈대를 마쳤다. Riverpod(`ProviderScope`)과 go_router(`app/router.dart`)를 연결했고, 첫 화면은 빈 여행 목록이다. 폴더 구조 규칙은 이 저장소 `CLAUDE.md`에 있다. 1-2단계를 나눠 만드는 순서(아래)를 제안해 두었고, 구현은 아직 시작하지 않았다.

## 다음에 할 첫 단계

**1-2단계 첫 단위: 여행 기본 (지도 없이)**

- `data/models`(Trip, Stop, Segment, Photo, 이동 수단, 여행 상태)와 메모리 `TripRepository`, 여행 목록·생성 화면, 여행 상태(전/중/후) 표시와 직접 변경, 제목 자동 생성("부산 2박 3일 봄 여행").
- 서버(1-1단계)가 아직 없어서 저장소는 메모리 구현으로 시작하고, 서버 API 연동 때 구현만 바꾼다.
- 그다음 순서 후보: 동선 페이지와 `MapProvider`(네이버) → 장소 편집·상세 시트 → 구간·이동 수단·화살표 → 곡선 핸들 → 서버 연동·로그인.
- 시작 전에 아래 "결론이 안 난 논의" 두 가지를 정한다.

## 현재 상태

- 디버그 빌드로 실행하면 여행 목록 빈 화면이 뜨고, 앱 바의 실험 아이콘으로 0단계 검증 화면(`/dev/snapshot-lab`)에 들어간다. 릴리스 빌드에는 이 경로가 없다.
- Flutter 3.47.7, AGP 9.1.0, go_router 17.5.0 상태로 Android 14 태블릿과 Android 10 휴대폰에서 여행 목록, 검증 화면 진입과 뒤로가기, 검증 화면 기능(스냅샷·합성·로고)을 확인했다. iOS는 맥이 없어서 확인하지 않았다.
- `main`과 `dev`는 같은 커밋(PR #1 머지)이다. `dev`는 아직 원격에 없어서 첫 push 때 `-u origin dev`로 올린다.

## 아직 문서에 없는 결정

- `linux/`, `macos/`, `windows/`, `web/`를 지우고 Android·iOS만 남겼다. 네이버 지도 SDK가 두 플랫폼만 지원하고, 계획도 Android → iOS뿐이기 때문이다. 필요하면 `flutter create --platforms=<플랫폼> .`으로 다시 만든다. 이 폴더들이 로컬에 비어서 남아 있으면 `flutter pub get` 때 플러그인 등록 파일이 다시 생기니 지운다.
- 앱 표시 이름은 `MapMarker`다 (Android `android:label`, iOS `CFBundleDisplayName`).
- 1단계 경로: `/login`, `/`(여행 목록), `/trips/new`, `/trips/:tripId`(동선 페이지, 일차 전환은 화면 상태), `/trips/:tripId/export`, `/settings`. 3단계에 `/shared/:shareId`(공유 링크 `/trip/<공유ID>`를 redirect로 연결). 장소 상세는 경로가 아니라 바텀 시트다.
- `MapProvider`는 Riverpod의 Provider와 이름이 겹치지만, 문서와 데이터 모델(지도 provider, `placeProvider`)에 맞추려고 이름을 그대로 둔다.
- **go_router는 17.x에 묶어 둔다.** go_router 18은 Material을 새 `material_ui` 패키지로 옮겼다. 그래서 `package:flutter/material.dart`의 `MaterialApp`을 쓰는 앱은 MaterialApp으로 알아보지 못하고, 모든 화면을 전환 애니메이션 없는 `NoTransitionPage`로 띄운다. Flutter 3.47 새 프로젝트 템플릿과 `flutter_naver_map`(로고 위젯 포함)이 아직 `flutter/material`을 써서 앱도 거기에 맞췄다. 플러그인들이 `material_ui`로 옮기면 앱 import와 함께 18로 올린다. 18로 올리면 `test/app/router_test.dart`의 Material 페이지 테스트가 실패한다.

## 결론이 안 난 논의

- **여행 생성 때 날짜(기간)를 받을지:** `PLAN.md` 1-2단계는 생성 입력을 "지역, 일정, 계절"로 적었지만, 여행 상태(전/중/후)는 기간으로 자동 판단한다. 기간이 없으면 자동 판단을 할 수 없다. 추천은 "지역(필수) + 기간(선택)"이다. 기간을 넣으면 일정·계절·상태를 자동으로 채우고, 없으면 일정·계절을 직접 고르고 상태는 "전"으로 둔다. 정해지면 `PLAN.md` 문구를 고친다.
- **서버 전 데이터 유지:** 메모리 저장소는 앱을 끄면 데이터가 사라진다. 추천은 디버그 빌드에서 샘플 여행 몇 개를 미리 넣는 것이다. 기기 저장은 2-2단계 오프라인 보기 때 함께 설계한다.

## 주의할 점

- Dart 패키지 이름은 `mapmarker_app`이다 (`pubspec.yaml`, `package:mapmarker_app/...`).
- 줄바꿈이 파일마다 다르다. `flutter create`가 만든 파일(`pubspec.yaml`, `analysis_options.yaml`, `README.md`, Android·iOS 설정 대부분)은 CRLF, `lib/`·`test/`와 문서는 LF, `.gitignore`는 섞여 있다. `.gitattributes`가 없어서 편집기나 스크립트가 줄바꿈을 바꾸면 diff 전체가 바뀌니, 커밋 전에 `git diff --stat`을 확인한다.
- Flutter를 올리면 마이그레이터가 프로젝트 파일을 자동으로 고친다. 3.47로 올릴 때는 `android/gradle.properties`(AGP 9 호환 설정, 이때 줄바꿈도 LF로 바뀌어 되돌렸다)와 `analysis_options.yaml`(`analyzer: exclude:`)이 바뀌었다. 둘 다 3.47 새 프로젝트 템플릿과 같은 내용이다.
- `android/gradle.properties`의 `android.newDsl=false`, `android.builtInKotlin=false`는 예전 Gradle 설정(`kotlinOptions`, `kotlin-android`)을 쓰는 플러그인(`flutter_naver_map` 등)과 호환하려는 것이니, 플러그인들이 새 방식으로 바뀌기 전에는 지우지 않는다.
- 빌드할 때 "`flutter_naver_map`이 Kotlin Gradle Plugin을 직접 적용한다, 나중 Flutter 버전에서는 빌드가 실패한다"는 경고가 나온다. 지금은 빌드되지만, Flutter를 올리기 전에 `flutter_naver_map`이 Built-in Kotlin을 지원하는 버전을 냈는지 확인한다(1.4.4가 2025-12 릴리스로 최신이다).
- 사진은 Android 사진 선택기로 고른다. 시스템 사진 선택기가 없는 기기(주로 Android 10 이하)는 Google Play 서비스의 사진 선택기 모듈로 열리는데, 이 모듈도 없으면 파일 앱으로 넘어가 다시 한 장만 선택된다. 앱 설치 때 모듈을 받게 하는 `AndroidManifest.xml` 항목(`ModuleDependencies`)을 넣을지는 1-3단계(사진)에서 정한다.
- `gradlew`를 직접 돌릴 때 JAVA_HOME이 없으면 실패한다. Android Studio의 `jbr` 폴더를 JAVA_HOME으로 지정한다. `flutter run`과 `flutter build`는 그대로 된다.

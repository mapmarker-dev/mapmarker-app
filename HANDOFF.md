# HANDOFF

> 최종 갱신: 2026-10-15 · 브랜치: test

## 지금 하는 일

0단계(준비) 중이다. 이미지 내보내기 기술 검증은 끝났고(코드는 `lib/prototype/`, 결론은 `PLAN.md` 0단계), 저장소 정리(Android·iOS 외 플랫폼 삭제, 앱 표시 이름 `MapMarker`)를 막 마쳤다.

## 다음에 할 첫 단계

**Flutter 앱 구조 결정:** 상태 관리(후보 Riverpod), 라우팅(후보 go_router, 3단계 공유 링크의 딥링크 처리 고려), 폴더 구조. 정해지면 `OVERVIEW.md` 기술 스택 표와 `PLAN.md` 0단계를 갱신한다.

## 현재 상태

- 앱을 실행하면 0단계 검증 화면(`SnapshotLabScreen`)이 바로 뜬다. 정식 화면은 아직 없다.
- 실기기 확인은 Android 14 태블릿과 Android 10 휴대폰에서 했다. iOS는 맥이 없어서 확인하지 않았다.
- 프로토타입은 `test` 브랜치에만 있다. `main`과 `dev`에는 아직 없다.
- 정리 후보
  - `lib/main.dart`의 `UnsupportedPlatformScreen`, `MapScreen`: 웹·데스크톱 폴더를 지운 뒤로 쓰이지 않는다.
  - `.env.example`의 `NAVER_MAP_CLIENT_SECRET`: Static Map API용이었는데 Static Map은 쓰지 않기로 해서, 지금은 읽는 코드가 없다.

## 아직 문서에 없는 결정

- `linux/`, `macos/`, `windows/`, `web/`를 지우고 Android·iOS만 남겼다. 네이버 지도 SDK가 두 플랫폼만 지원하고, 계획도 Android → iOS뿐이기 때문이다. 필요하면 `flutter create --platforms=<플랫폼> .`으로 다시 만든다.
- 앱 표시 이름은 `MapMarker`다 (Android `android:label`, iOS `CFBundleDisplayName`).

## 결론이 안 난 논의

- `test` 브랜치의 프로토타입과 저장소 정리 커밋을 `dev`·`main`에 어떻게 합칠지 정하지 않았다. 정리 커밋만 가져갈지, 1-5단계 이미지 내보내기 구현 때 쓰려고 프로토타입까지 합칠지 정해야 한다.

## 주의할 점

- Dart 패키지 이름은 `mapmarker_app`이다 (`pubspec.yaml`, `package:mapmarker_app/...`).
- 파일 대부분이 CRLF 줄바꿈으로 커밋돼 있다. 편집기나 스크립트가 줄바꿈을 바꾸면 diff 전체가 바뀌니, 커밋 전에 `git diff --stat`을 확인한다.
- 사진은 Android 사진 선택기로 고른다. 시스템 사진 선택기가 없는 기기(주로 Android 10 이하)는 Google Play 서비스의 사진 선택기 모듈로 열리는데, 이 모듈도 없으면 파일 앱으로 넘어가 다시 한 장만 선택된다. 앱 설치 때 모듈을 받게 하는 `AndroidManifest.xml` 항목(`ModuleDependencies`)을 넣을지는 1-3단계(사진)에서 정한다.
- `gradlew`를 직접 돌릴 때 JAVA_HOME이 없으면 실패한다. Android Studio의 `jbr` 폴더를 JAVA_HOME으로 지정한다. `flutter run`과 `flutter build`는 그대로 된다.

# HANDOFF

> 최종 갱신: 2026-11-04 · 브랜치: dev

## 지금 하는 일

앱 작업은 쉬고 있다. 1-2단계 지도·동선 편집은 갤럭시 휴대폰·탭에서 확인하고 `main`에 병합했다(PR #2). 서버 1-1단계(로그인 포함)는 서버 `main`에 병합했다(서버 PR #4, `../mapmarker-server/HANDOFF.md`). 다음은 이 저장소의 서버 연동·로그인 단위다. 앱 CI는 서버가 좀 개발된 뒤에 넣는다(`.github` HANDOFF).

## 다음에 할 첫 단계

1. **다음 앱 단위: 서버 연동·로그인**(PLAN 1-2 마지막 항목). 서버의 로그인·재발급·로그아웃과 Trip/Stop/Segment API(PLAN 1-1)는 서버 `main`에 있다. 시작 전에 PLAN·OVERVIEW와 서버 `HANDOFF.md`를 보고 범위·순서를 사용자와 정한다.
   - 로그인: 카카오는 SDK의 `idToken`(콘솔에서 OpenID Connect를 켜 두었다), 네이버는 access token을 서버에 보낸다. 카카오 콘솔에는 지금 개발 PC 한 대의 debug 키 해시만 있어서, 다른 PC에서 빌드하면 그 PC의 키 해시를 "앱 → 플랫폼 키 → 네이티브 앱 키"에 더한다. 토큰 재발급은 한 번에 하나만 보낸다. 자세한 것은 서버 `HANDOFF.md` "다음 단위로 넘길 것".
   - `TripRepository`는 화면이 구독하는 스트림과 쓰기 메서드로 되어 있다. 서버 구현은 받아 온 여행을 기억해 두고, 이 앱에서 바꾼 내용을 반영해 다시 내보내야 한다. 이 부분은 2-2단계 오프라인 보기와 함께 설계한다.
   - 1단계에 더할 경로: `/login`, `/trips/:tripId/export`, `/settings`. 3단계에 `/shared/:shareId`(공유 링크 `/trip/<공유ID>`를 redirect로 연결). 지금 경로는 `app/router.dart`에 있다.
   - 디버그 빌드의 샘플 여행은 메모리 저장소가 앱을 끄면 비어서 넣는 것이다. 서버 저장소로 바꿀 때 어떻게 할지 정한다.

## 현재 상태

- `flutter analyze` 문제 0건, `flutter test` 407개 통과.
- 디버그 빌드는 시작할 때 샘플 여행 3개를 넣는다(`lib/dev/sample_trips.dart`). 제주(중: 연박, 숙소 옮김, 종류 4개, 선 모양 3갈래·갈아타기·미정, 곡선), 강릉(전: 날짜 미정, 장소 없음), 부산(후: 2일차 비움). 테스트는 빈 저장소로 시작한다.
- 끌어 옮기기는 아직 그날 밤 숙소 뒤로도 갈 수 있다(장소 입력 화면의 "넣을 자리" 칸은 막는다).
- 내보내기 합성(`features/export/route_composer.dart`, 0단계 프로토타입)은 아직 자기 색(#1E6FFF)과 글꼴 크기를 쓴다. 1-5단계에서 토큰으로 바꾸고, "숙소 포함" 끄기는 `RouteView.vias`("숙소를 거침" 선)로 그린다.

## 결론이 안 난 논의

- **네이버 로그인 Client Secret:** 네이버 네이티브 SDK(`flutter_naver_login` 2.1.1)는 Client ID와 함께 Client Secret을 앱에 넣어야 한다(`AndroidManifest`의 `com.naver.sdk.clientSecret`). 앱 `CLAUDE.md`의 "비밀값은 앱 코드에서 읽지 않는다"와 부딪혀서 서버 연동 단위를 시작할 때 사용자와 정한다. 커밋은 하지 않는다(`.env` 등). 이 플러그인은 Android에서 Client Secret을 `println`으로 로그에 찍으니 다른 방법(플러그인 수정·다른 패키지)도 그때 본다. 서버는 이 값이 필요 없다.
- 미룬 후보: 구간 줄에서 "이 사이에 장소 넣기"(지도 탭 흐름 손질이 커서), 지워진 이동 수단 되살리기(OVERVIEW 규칙 변경과 서버 저장 설계가 필요하다. 대안은 [실행 취소] 스낵바), 가까운 자리로 자동 넣기(틀릴 때 이유를 알 수 없어 권하지 않는다).
- 카드에 동선 미리보기나 사진을 넣을지는 1-5단계(이미지 내보내기) 때 다시 본다.
- 영어를 넣는 시점과 언어를 고르는 방식은 아직 정하지 않았다(PLAN "아직 확인할 것"). 지금은 `appLocale`(ko)로 고정했다. 넣을 때 `MaterialApp`의 `locale`과 `l10nProvider`가 같은 언어를 쓰게 맞추고, iOS `Info.plist`에 `CFBundleLocalizations`(ko, en)를 더한다.
- 남반구 해외 여행은 계절이 반대가 된다. 2단계에서 다시 본다.

## 주의할 점

- 빌드할 때 "`flutter_naver_map`이 Kotlin Gradle Plugin을 직접 적용한다, 나중 Flutter 버전에서는 빌드가 실패한다"는 경고가 나온다. 지금은 빌드된다. Flutter를 올리기 전에 `flutter_naver_map`이 Built-in Kotlin을 지원하는 버전을 냈는지 확인한다(2025-12의 1.4.4가 최신이었다).
- 나중에 챙길 것
  - 2-1단계 구글 지도 구현에도 `MapLineStyle.faint`("숙소를 거침" 선: 무늬, 굵기, 탭 없음, 가장 아래)를 맞춘다.
  - 다크 모드를 넣을 때 `routeViaOpacity`를 따로 본다(어두운 바탕에서 더 묻힌다).
  - 설정 화면(`/settings`)을 만들 때 글꼴 라이선스(`main.dart`에서 등록)를 `showLicensePage`로 열게 한다.
  - 1-3단계(사진): 시스템 사진 선택기가 없는 기기(주로 Android 10 이하)는 Google Play 서비스의 선택기 모듈로, 그것도 없으면 파일 앱으로 열린다. 설치 때 모듈을 받게 하는 `AndroidManifest.xml` 항목(`ModuleDependencies`)을 넣을지 이때 정한다.
- 작업 요령(네이버 SDK, 위젯 테스트, 의존성 고정, 줄바꿈)은 `CLAUDE.md`에 있다. 화면 동작의 세부 규칙과 이유는 코드 주석과 테스트에 있다.

@../.github/CLAUDE.md

# mapmarker-app

MapMarker의 Flutter 앱 (Dart SDK ^3.12.0). 소스는 `lib/`, 테스트는 `test/`. 원격 저장소는 `mapmarker-dev/mapmarker-app`.

## 명령어

- 의존성 설치: `flutter pub get`
- 정적 분석: `flutter analyze`
- 테스트: `flutter test`
- 실행: `flutter run --dart-define-from-file=.env` (VS Code는 `.vscode/launch.json`에 설정돼 있음)

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
├─ core/            기능에 속하지 않는 공용 코드 (곡선 계산, 지도 인터페이스 등)
├─ features/<기능>/  화면과 상태(Riverpod). 예: trips, trip_detail, export
└─ dev/             개발용 화면. 경로는 디버그 빌드에서만 등록한다
```

- 폴더는 파일이 생길 때 만든다. `test/`는 `lib/`와 같은 구조로 둔다.
- 기능 폴더는 `xxx_screen.dart`, `xxx_controller.dart`(Notifier), `widgets/`로 시작하고, 파일이 많아지면 나눈다.
- 기능끼리는 서로 import하지 않는다. 같이 쓸 코드는 `data/`나 `core/`로 옮긴다.
- 화면은 경로로 이동한다(`context.go(Routes.xxx)`). 새 화면은 `app/router.dart`의 여행 목록(`/`) 아래에 등록한다. 딥링크로 바로 열어도 뒤로가기가 여행 목록으로 가게 하기 위해서다.
- 상태 관리는 Riverpod을 코드 생성 없이 쓴다.

## 코딩 규칙

- `flutter_lints` 규칙(`analysis_options.yaml`)을 따른다.
- 커밋 전에 `flutter analyze`와 `flutter test`가 통과하는지 확인한다.
- iOS를 지원하지 않는 패키지는 쓰지 않는다 (iOS는 MVP 이후 출시 예정).

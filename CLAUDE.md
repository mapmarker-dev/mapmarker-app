@../.github/CLAUDE.md

# mapmarker-app

MapMarker의 Flutter 앱 (Dart SDK ^3.9.2). 소스는 `lib/`, 테스트는 `test/`. 원격 저장소는 `mapmarker-dev/mapmarker-app`.

## 명령어

- 의존성 설치: `flutter pub get`
- 정적 분석: `flutter analyze`
- 테스트: `flutter test`
- 실행: `flutter run`

## 코딩 규칙

- `flutter_lints` 규칙(`analysis_options.yaml`)을 따른다.
- 커밋 전에 `flutter analyze`와 `flutter test`가 통과하는지 확인한다.
- iOS를 지원하지 않는 패키지는 쓰지 않는다 (iOS는 MVP 이후 출시 예정).

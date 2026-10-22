# mapmarker-app

[MapMarker](https://github.com/mapmarker-dev)의 Flutter 앱입니다. 여행 동선(장소, 구간별 이동 수단, 곡선)을 지도 위에 그리고, 일차별로 보고 고칩니다.

## 지금 상태

- 1단계(MVP) 중 앱의 지도·동선 편집을 마쳤습니다. 여행 목록과 만들기, 여행 동선 페이지(네이버 지도), 일차 동선 시트, 장소·이동 수단·곡선 편집이 됩니다.
- 서버 연동과 로그인은 아직입니다. 데이터는 메모리에만 있어서 앱을 끄면 사라집니다. 디버그 빌드는 샘플 여행 3개로 시작합니다.
- Android만 지원합니다. iOS는 MVP 이후에 넣습니다.

단계별 계획은 [PLAN](https://github.com/mapmarker-dev/.github/blob/main/docs/PLAN.md)에 있습니다.

## 준비물

- Flutter 3.47(stable), Dart SDK ^3.12.0
- Android 기기나 에뮬레이터
- 네이버 클라우드 플랫폼 지도(Maps) Client ID. 콘솔에서 이 앱의 패키지 이름으로 사용을 제한합니다(앱에 들어가는 키는 숨길 수 없어서).

## 시작하기

저장소들을 같은 폴더 아래에 나란히 클론합니다. 이 저장소의 `CLAUDE.md`가 `../.github/CLAUDE.md`의 공통 규칙을 불러오기 때문입니다.

```bash
git clone https://github.com/mapmarker-dev/.github.git
git clone https://github.com/mapmarker-dev/mapmarker-app.git
cd mapmarker-app
```

`.env.example`을 `.env`로 복사하고 `NAVER_MAP_CLIENT_ID`를 채웁니다. `.env`는 커밋하지 않습니다.

```bash
cp .env.example .env
```

의존성을 받고(다국어 코드도 이때 만들어집니다) 실행합니다. VS Code는 `.vscode/launch.json`에 같은 설정이 있습니다.

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

## 명령어

| 하는 일 | 명령어 |
|---|---|
| 의존성 설치, 다국어 코드 생성 | `flutter pub get` |
| 정적 분석 | `flutter analyze` |
| 테스트(단위 + 위젯) | `flutter test` |
| 실행 | `flutter run --dart-define-from-file=.env` |

커밋 전에 `flutter analyze`와 `flutter test`가 통과해야 합니다. 테스트는 실제 지도 대신 가짜 지도(`test/helpers/fake_map.dart`)를 씁니다.

## 폴더 구조

```
lib/
├─ main.dart        SDK 초기화 → ProviderScope → MapMarkerApp
├─ app/             MaterialApp, 경로 표(go_router)
├─ config/          환경 변수(Env)
├─ data/            모델, 저장소. 여러 기능이 함께 쓴다
├─ core/            디자인 토큰·테마, 지도 인터페이스(MapProvider)와 네이버 구현, 곡선 계산
├─ features/        화면과 상태(Riverpod): trips, trip_detail, export
├─ l10n/            화면 글자(app_ko.arb)
└─ dev/             디버그 빌드 전용 화면과 샘플 여행
```

`test/`는 `lib/`와 같은 구조입니다. 코드 규칙(다국어, 디자인 토큰, 브랜치 운영)은 [CLAUDE.md](CLAUDE.md)에 있습니다.

## 문서

- [큰 그림과 결정 이유 (OVERVIEW)](https://github.com/mapmarker-dev/.github/blob/main/docs/OVERVIEW.md)
- [단계별 계획 (PLAN)](https://github.com/mapmarker-dev/.github/blob/main/docs/PLAN.md)
- [작업 인수인계 (HANDOFF.md)](HANDOFF.md): 지금 하는 일, 다음 단계, 주의할 점

## 글꼴

나눔스퀘어라운드(네이버)를 SIL Open Font License 1.1로 넣었습니다. 고지와 전문은 [assets/fonts/OFL.txt](assets/fonts/OFL.txt)에 있습니다.

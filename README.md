# mapmarker-app

[MapMarker](https://github.com/mapmarker-dev)의 Flutter 앱입니다. 여행 동선(장소, 구간별 이동 수단, 곡선)을 지도 위에 그리고, 일차별로 보고 고칩니다.

## 지금 상태

1단계(MVP)를 진행하고 있습니다. Android만 지원합니다(iOS는 MVP 이후). 계획은 [PLAN](https://github.com/mapmarker-dev/.github/blob/main/docs/PLAN.md)에 있습니다.

- 카카오·네이버 로그인, 여행 목록과 만들기·지우기(휴지통), 네이버 지도 위 여행 동선과 일차 동선 시트
- 장소·이동 수단·곡선 편집, 후보 장소, 주소로 장소 찾기와 동선 사이 ⊕
- 장소 사진 1장: 줄이고 위치 정보를 지운 뒤 S3에 직접 올리고, 장소 줄과 지도 마커에 썸네일로 보입니다
- 여행 중: 현재 위치("앱 사용 중" 권한만)와 가까운 순 후보, 방문 완료와 실제 방문 시각(장소 현지 시각)
- 모두 서버([mapmarker-server](https://github.com/mapmarker-dev/mapmarker-server))에 저장되고, 보기 전용 제주 샘플 여행을 [실제로 사용하기]로 가져갑니다

## 시작하기

Flutter 3.47(stable, Dart ^3.12.0), Android 기기나 에뮬레이터, 로컬에서 돌아가는 서버가 필요합니다. 키는 네이버 클라우드 플랫폼 지도 Client ID, 카카오 네이티브 앱 키, 네이버 로그인 Client ID·Secret이고, 앱에 들어가는 키는 숨길 수 없어서 각 콘솔에서 패키지 이름(카카오는 키 해시도)으로 사용을 제한합니다.

저장소들을 같은 폴더 아래에 나란히 클론합니다(`CLAUDE.md`가 `../.github/CLAUDE.md`를 불러옵니다).

```bash
git clone https://github.com/mapmarker-dev/.github.git
git clone https://github.com/mapmarker-dev/mapmarker-app.git
cd mapmarker-app
cp .env.example .env
```

`.env`와 `android/local.properties`(네이버 로그인 값)를 채웁니다. 둘 다 커밋하지 않으며, 값의 위치와 서버에 붙는 순서는 [CLAUDE.md](CLAUDE.md)에 있습니다. VS Code는 `.vscode/launch.json`에 같은 설정이 있습니다.

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

커밋 전에 `flutter analyze`와 `flutter test`가 통과해야 합니다. 테스트는 실제 지도·서버·카카오·네이버 대신 가짜(`test/helpers/`)를 씁니다.

## 폴더 구조

```
lib/
├─ main.dart        SDK 초기화 → ProviderScope → MapMarkerApp
├─ app/             MaterialApp, 경로 표(go_router)
├─ config/          환경 변수(Env)
├─ data/            모델, 저장소, 서버 API, 로그인, 샘플 여행. 여러 기능이 함께 쓴다
├─ core/            디자인 토큰·테마, 지도 인터페이스(MapProvider)와 네이버 구현, 곡선 계산
├─ features/        화면과 상태(Riverpod): login, trips, trip_detail, trash, export
├─ l10n/            화면 글자(app_ko.arb)
└─ dev/             디버그 빌드 전용 화면
```

`test/`는 `lib/`와 같은 구조입니다.

## 문서

[OVERVIEW](https://github.com/mapmarker-dev/.github/blob/main/docs/OVERVIEW.md)(큰 그림과 결정 이유), [CLAUDE.md](CLAUDE.md)(코드 규칙), [HANDOFF.md](HANDOFF.md)(지금 하는 일과 주의할 점)

## 글꼴

나눔스퀘어라운드(네이버)를 SIL Open Font License 1.1로 넣었습니다. 고지와 전문은 [assets/fonts/OFL.txt](assets/fonts/OFL.txt)에 있습니다.

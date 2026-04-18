# app-release

크로스 스택 모바일 앱 스토어 릴리즈 파이프라인. Expo / Capacitor 1차 지원, Flutter 스텁.

## 설치

```bash
claude /plugin install app-release@gprecious-marketplace
cd ~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release && npm install
```
`npm install`은 **플러그인 업데이트 후에도** 재실행해야 한다(의존성 갱신).

## 프로젝트 설정 — `release.config.json`

각 모바일 프로젝트 루트에 다음 파일을 둔다 (Expo의 경우 `mobile/`, Capacitor는 `frontend/` 등).

```jsonc
{
  "stack": "expo",
  "appName": "MyApp",
  "ios": {
    "bundleId": "com.example.myapp",
    "ascAppId": "1234567890",
    "ascKeyId": "XXXXXXXX",
    "ascIssuerId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "ascKeyPath": "./keys/asc-api-key.p8"
  },
  "android": {
    "packageName": "com.example.myapp",
    "serviceAccountPath": "./keys/google-play-service-account.json",
    "track": "internal"
  },
  "paths": {
    "fastlane": "./fastlane",
    "screenshotsSource": "./screenshots/raw",
    "screenshotsOutput": "./fastlane/screenshots"
  },
  "store": {
    "apple": { "info": { "en-US": { "description": "...", "keywords": "..." } } },
    "android": { "info": { "en-US": { "title": "...", "shortDescription": "...", "fullDescription": "..." } } }
  }
}
```

Expo의 경우 `appName`, `ios.bundleId`, `android.packageName`은 `app.json`에서 자동 임포트되므로 생략 가능.

## 사용

| 명령 | 설명 |
|---|---|
| `/release-status` | 심사 상태 조회 |
| `/release-metadata` | 메타데이터 dry-run → 사용자 확인 → 적용 |
| `/release-screenshots` | 스크린샷 생성 + Fastlane 업로드 |
| `/release-promote` | 프로덕션 승격 |
| `/release-fix` | 거절 대응 분석 |
| `/release` | 전체 파이프라인 |

## 스택별 요구사항

- **Expo**: `eas-cli` 설치, `eas.json` 작성, `keys/` 에 ASC .p8 / Play 서비스 계정
- **Capacitor**: `release.config.json.capacitor.iosProjectPath`/`androidProjectPath` 명시, Xcode + Ruby + Fastlane 설치
- **Flutter**: 미구현

## 트러블슈팅

- `release.config.json not found`: cwd에서 상위로 탐색 중 못 찾음. 프로젝트 루트에 파일을 만들거나 `RELEASE_PROJECT_ROOT=/path/to/root` 환경변수 설정.
- `node_modules missing`: 플러그인 디렉터리에서 `npm install`.
- `jsonwebtoken` 관련 에러: `npm install` 재실행.

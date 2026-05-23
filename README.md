# gprecious-marketplace

Claude Code 및 OpenCode 플러그인 마켓플레이스

## 폴더 구조

```
gprecious-marketplace/
├── .claude-plugin/
│   └── marketplace.json     # marketplace 카탈로그 (SoT)
├── claude-plugins/          # Claude Code 플러그인
│   ├── app-release/
│   ├── cmux/
│   └── herdr/
└── opencode-plugins/        # OpenCode 플러그인
    └── youtube-shorts-orchestrator/
```

## Claude Code 플러그인

| 플러그인 | 설명 | 소스 |
|---------|------|------|
| research-engine | YouTube/arXiv/GitHub/blog/topic 심층 분석 + Notion 미러링 + /research-visualize (차트·Mermaid·PPT 슬라이드) | 외부 repo (`github.com/gprecious/research-engine`) |
| app-release | 크로스 스택 모바일 스토어 릴리즈 파이프라인 (Expo/Capacitor). ASC + Play 메타데이터/스크린샷/상태/승격/거절대응 자동화 | `claude-plugins/app-release` |
| cmux | cmux 멀티페인 위에서 Claude Code/Codex 세션을 역할별 페인(plan/design/test/dev/review)으로 자동 오케스트레이션. 패널 간 메시지 송수신 skill 포함 | `claude-plugins/cmux` |
| herdr | herdr 위에서 Claude Code + Codex 워커 N개를 3×3 grid (한 탭 최대 9개) + 탭 spillover 로 병렬 spawn / 대기 / 결과 회수 / 자동 정리 | `claude-plugins/herdr` |

### 설치 방법

```bash
claude /install research-engine@gprecious-marketplace
claude /install app-release@gprecious-marketplace
claude /install cmux@gprecious-marketplace
claude /install herdr@gprecious-marketplace

# app-release 는 최초 설치 후 한 번:
cd ~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release && npm install
```

## OpenCode 플러그인

| 플러그인 | 설명 | 경로 |
|---------|------|------|
| youtube-shorts-orchestrator | 다국어 YouTube Shorts 채널 통합 관리 (8개 언어, 연령대별 3채널) | `opencode-plugins/youtube-shorts-orchestrator` |

### 설치 방법

OpenCode CLI를 통해 설치:

```bash
opencode plugin add youtube-shorts-orchestrator
```

또는 프로젝트에서 직접 사용:

```bash
# opencode.json에 추가
{
  "plugins": ["youtube-shorts-orchestrator"]
}
```

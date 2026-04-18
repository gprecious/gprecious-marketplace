# gprecious-marketplace

Claude Code 및 OpenCode 플러그인 마켓플레이스

## 폴더 구조

```
gprecious-marketplace/
├── claude-plugins/           # Claude Code 플러그인
│   ├── ultrawork/
│   ├── youtube-assistant/
│   └── youtube-shorts-orchestrator/
└── opencode-plugins/         # OpenCode 플러그인
    └── youtube-shorts-orchestrator/
```

## Claude Code 플러그인

| 플러그인 | 설명 | 경로 |
|---------|------|------|
| ultrawork | Sisyphus/Ultrawork 패턴 병렬 에이전트 오케스트레이션 | claude-plugins/ultrawork |
| youtube-assistant | 유튜브 영상 제작 도우미 (스크립트 첨삭, 트렌드 분석, 음악 추천) | claude-plugins/youtube-assistant |
| youtube-shorts-orchestrator | 다국어 YouTube Shorts 채널 통합 관리 (8개 언어, 연령대별 3채널) | claude-plugins/youtube-shorts-orchestrator |
| harness | TDD Generator-Evaluator 파이프라인 (Plan-Contract-Test-Build-Evaluate-Integrate-Learn) | claude-plugins/harness |
| research-engine | YouTube/arXiv/GitHub/blog/topic 심층 분석 + Notion 미러링 | (외부 repo) |
| app-release | 크로스 스택 모바일 스토어 릴리즈 파이프라인 (Expo/Capacitor). ASC + Play 메타데이터/스크린샷/상태/승격/거절대응 자동화 | claude-plugins/app-release |

### 설치 방법

```bash
claude /install ultrawork@gprecious-marketplace
claude /install youtube-assistant@gprecious-marketplace
claude /install youtube-shorts-orchestrator@gprecious-marketplace
claude /install harness@gprecious-marketplace
claude /install app-release@gprecious-marketplace
# app-release는 최초 설치 후 한 번:
# cd ~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release && npm install
```

## OpenCode 플러그인

| 플러그인 | 설명 | 경로 |
|---------|------|------|
| youtube-shorts-orchestrator | 다국어 YouTube Shorts 채널 통합 관리 (8개 언어, 연령대별 3채널) | opencode-plugins/youtube-shorts-orchestrator |

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

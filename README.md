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

### 설치 방법

```bash
claude /install ultrawork@gprecious-marketplace
claude /install youtube-assistant@gprecious-marketplace
claude /install youtube-shorts-orchestrator@gprecious-marketplace
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

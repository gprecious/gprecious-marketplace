# gprecious-marketplace

Claude Code, Codex, OpenCode 플러그인 마켓플레이스

## 폴더 구조

```
gprecious-marketplace/
├── .claude-plugin/
│   └── marketplace.json     # marketplace 카탈로그 (SoT)
├── .agents/plugins/
│   ├── marketplace.json     # Codex marketplace 카탈로그
│   └── plugins/             # Codex plugin manifests + skills
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
| hetzner-master | Hetzner Proxmox VE 8 lab 배포·운영 runbook. LXC, Terraform state safety, Ansible rollout, Tailscale, monitoring 포함 | 외부 repo (`github.com/gprecious/hetzner-master`) |

### 설치 방법

```bash
claude /install research-engine@gprecious-marketplace
claude /install app-release@gprecious-marketplace
claude /install cmux@gprecious-marketplace
claude /install herdr@gprecious-marketplace
claude /install hetzner-master@gprecious-marketplace

# app-release 는 최초 설치 후 한 번:
cd ~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release && npm install
```

## Codex 플러그인

Claude marketplace에 있는 플러그인은 모두 Codex marketplace에도 노출한다. OpenCode 전용으로 시작한 `youtube-shorts-orchestrator`도 Codex skill 형태로 이식되어 있다.

| 플러그인 | 설명 | 경로 |
|---------|------|------|
| research-engine | URL/topic 리서치 → cited markdown report | `.agents/plugins/plugins/research-engine` |
| app-release | 모바일 앱 스토어 릴리즈 workflow | `.agents/plugins/plugins/app-release` |
| cmux | cmux 기반 멀티-agent orchestration | `.agents/plugins/plugins/cmux` |
| herdr | herdr 기반 worker pane orchestration | `.agents/plugins/plugins/herdr` |
| youtube-shorts-orchestrator | YouTube Shorts 제작 workflow | `.agents/plugins/plugins/youtube-shorts-orchestrator` |
| hetzner-master | Hetzner Proxmox lab deploy/ops runbook | `.agents/plugins/plugins/hetzner-master` |

### 설치 방법

로컬 checkout에서:

```bash
codex plugin marketplace add /path/to/gprecious-marketplace
codex plugin add research-engine@gprecious-marketplace
codex plugin add app-release@gprecious-marketplace
codex plugin add cmux@gprecious-marketplace
codex plugin add herdr@gprecious-marketplace
codex plugin add youtube-shorts-orchestrator@gprecious-marketplace
codex plugin add hetzner-master@gprecious-marketplace
```

GitHub에서 직접 추가할 때는 repo root 아래 `.agents/plugins`만 sparse checkout하면 된다:

```bash
codex plugin marketplace add gprecious/gprecious-marketplace --sparse .agents/plugins
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

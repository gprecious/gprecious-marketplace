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
│   ├── goalcraft/
│   ├── growth-marketer/
│   ├── herdr/
│   └── session-journal/
└── opencode-plugins/        # OpenCode 플러그인
    └── youtube-shorts-orchestrator/
```

## Claude Code 플러그인

| 플러그인 | 설명 | 소스 |
|---------|------|------|
| research-engine | YouTube/arXiv/GitHub/blog/topic 심층 분석 + Notion 미러링 + /research-visualize (차트·Mermaid·PPT 슬라이드) | 외부 repo (`github.com/gprecious/research-engine`) |
| app-release | 크로스 스택 모바일 스토어 릴리즈 파이프라인 (Expo/Capacitor). ASC + Play 메타데이터/스크린샷/상태/승격/거절대응 자동화 | `claude-plugins/app-release` |
| cmux | cmux 멀티페인 위에서 Claude Code/Codex 세션을 역할별 페인(plan/design/test/dev/review)으로 자동 오케스트레이션. 패널 간 메시지 송수신 skill 포함 | `claude-plugins/cmux` |
| herdr | herdr 위에서 Claude Code + Codex 워커를 visible TUI pane 으로 병렬 실행. v0.10 라우팅 게이트로 subagent/lightweight delegation 을 먼저 검토하고, visible TUI·별도 CLI/account/browser state·명시적 pane fan-out 이 필요할 때만 새 pane 생성 (3×3 grid + 탭 spillover, 자동 정리) | `claude-plugins/herdr` |
| hetzner-master | Hetzner Proxmox VE 8 lab 배포·운영 runbook. LXC, Terraform state safety, Ansible rollout, Tailscale, monitoring, Supabase self-hosted LXC 템플릿(프로젝트별 복제) 포함 | 외부 repo (`github.com/gprecious/hetzner-master`) |
| growth-marketer | 모바일 앱·웹/SaaS 마케팅 자동화. 서비스 분석(ICP·VOC) → 채널 추천 → 카피·플레이북·CRO·draft 캠페인 | `claude-plugins/growth-marketer` |
| goalcraft | 요구사항·버그·작업 설명을 실행 주체(Claude Code/Codex)에 맞춘 goal 최적화 프롬프트로 변환. executor-adaptive — 누락 필드(완료조건·범위·검증) 질문 후 복붙용 프롬프트 생성, 장기작업은 /goal 활용 | `claude-plugins/goalcraft` |
| session-journal | Claude Code/Codex 세션을 Obsidian vault에 기록 — 일자별 단일 노트(`Journal/<date>.md`)에 의미있는 세션만 시간순 요약(throwaway 세션 skip), raw 로그는 vault 밖(`$XDG_STATE_HOME`, retention), verbatim 전사·자동 wiki 없음, 모두 #ai-generated 태깅 | `claude-plugins/session-journal` |

### 설치 방법

```bash
claude /install research-engine@gprecious-marketplace
claude /install app-release@gprecious-marketplace
claude /install cmux@gprecious-marketplace
claude /install herdr@gprecious-marketplace
claude /install hetzner-master@gprecious-marketplace
claude /install growth-marketer@gprecious-marketplace
claude /install goalcraft@gprecious-marketplace
claude /install session-journal@gprecious-marketplace

# app-release 는 최초 설치 후 한 번:
cd ~/.claude/plugins/marketplaces/gprecious-marketplace/claude-plugins/app-release && npm install

# session-journal vault (기본값: ~/Documents/Obsidian/llm-agent-vault)
# 기존 Obsidian vault 하위폴더에 합치기 — 멀티 머신은 이름 기반 권장 (각 머신
# obsidian.json 으로 로컬 경로 자동 해석, 콘텐츠는 Obsidian Sync 가 전파):
export LLM_OBSIDIAN_VAULT_NAME="harry"      # Obsidian vault 이름
export LLM_OBSIDIAN_SUBDIR="AI-Journal"     # 그 안의 전용 하위폴더
# 같은 이름 vault 가 2개 이상이면(예: 로컬+iCloud) 절대경로 1개로 고정해 split-brain 방지:
#   export LLM_OBSIDIAN_VAULT="$HOME/Documents/obsidian/<vault>/AI-Journal"
# AI 생성 노트는 모두 #ai-generated 태그가 붙어 내 노트와 구별됨. (`where` 로 해석 확인)
```

## Codex 플러그인

Claude marketplace에 있는 플러그인은 모두 Codex marketplace에도 노출한다. OpenCode 전용으로 시작한 `youtube-shorts-orchestrator`도 Codex skill 형태로 이식되어 있다.

| 플러그인 | 설명 | 경로 |
|---------|------|------|
| research-engine | URL/topic 리서치 → cited markdown report | `.agents/plugins/plugins/research-engine` |
| app-release | 모바일 앱 스토어 릴리즈 workflow | `.agents/plugins/plugins/app-release` |
| cmux | cmux 기반 멀티-agent orchestration | `.agents/plugins/plugins/cmux` |
| herdr | herdr 기반 worker pane orchestration (v0.10 subagent-우선 라우팅 게이트) | `.agents/plugins/plugins/herdr` |
| youtube-shorts-orchestrator | YouTube Shorts 제작 workflow | `.agents/plugins/plugins/youtube-shorts-orchestrator` |
| hetzner-master | Hetzner Proxmox lab deploy/ops runbook | `.agents/plugins/plugins/hetzner-master` |
| growth-marketer | 모바일 앱·웹/SaaS 마케팅 자동화. 서비스 분석 → 채널 추천 → 카피·플레이북 | `.agents/plugins/plugins/growth-marketer` |
| goalcraft | 요구사항을 실행 주체(Claude Code/Codex)에 맞춘 goal 최적화 프롬프트로 변환. executor-adaptive + 누락 필드 질문 + /goal 장기작업 | `.agents/plugins/plugins/goalcraft` |
| session-journal | Codex/Claude hook 이벤트를 일자별 단일 노트(`Journal/<date>.md`, 의미있는 세션만 시간순)로 저장, raw log는 vault 밖(`$XDG_STATE_HOME`, retention) (verbatim 전사·자동 wiki 없음, #ai-generated 태깅) | `.agents/plugins/plugins/session-journal` |

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
codex plugin add growth-marketer@gprecious-marketplace
codex plugin add goalcraft@gprecious-marketplace
codex plugin add session-journal@gprecious-marketplace
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

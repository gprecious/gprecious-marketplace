# Claude Code Plugin 개발 규칙

이 repo 는 **gprecious-marketplace** — Claude Code / OpenCode plugin marketplace.
단일 진실 공급원은 `./.claude-plugin/marketplace.json`.

## 폴더 구조

```
gprecious-marketplace/
├── .claude-plugin/
│   └── marketplace.json     # Claude Code 카탈로그 (SoT)
├── .agents/plugins/
│   ├── marketplace.json     # Codex 카탈로그 (Claude 카탈로그와 함께 유지)
│   └── plugins/<p>/         # Codex plugin 소스 (.codex-plugin/plugin.json)
├── claude-plugins/          # Claude Code plugin 소스 (.claude-plugin/plugin.json)
├── opencode-plugins/        # OpenCode plugin 소스
├── scripts/                 # 유지보수 도구 (dual-tree-check.py 등)
└── README.md                # 사용자용 안내 (marketplace.json 변경 시 동기화 필요)
```

## 원격 동기화 (필수 — HARD RULE)

이 marketplace 는 **다른 머신·다른 사용자가 GitHub origin(`gprecious/gprecious-marketplace`)에서 받아 쓰는 공유 카탈로그**다. 로컬 commit 만 해두면 다른 머신에서 `marketplace update` 해도 안 보인다 (실제로 발생한 사고: plugin 등록 19 커밋이 push 안 돼 다른 머신에서 안 보임).

- **marketplace.json / plugin 소스 / README 를 바꿔 commit 했으면, 작업 마무리 전에 반드시 `git push origin main` 까지 한다.** "commit 완료 = 작업 끝" 이 아니다. "push 완료 = 작업 끝".
- 완료 보고 전 `git status -sb` 로 `ahead` 가 남아있지 않은지 확인한다. `[ahead N]` 이 보이면 아직 안 끝난 것.
- push 는 공유 원격을 바꾸는 행위이므로 진행 직전 사용자에게 한 번 알리되, marketplace 변경 작업의 정상 종료 단계로 취급한다 (빠뜨리지 말 것).
- push 전 `gh auth status` + `git remote -v` 로 owner 가 `gprecious` 계정인지 확인 (글로벌 규칙).

## 이중 트리(dual-landing) 동기 (필수 — HARD RULE)

한 플러그인이 **두 트리에 따로** 존재한다. 각 런타임이 보는 경로가 다르기 때문이다:

| 런타임 | 카탈로그 | 플러그인 소스 | 매니페스트 |
| --- | --- | --- | --- |
| Claude Code | `.claude-plugin/marketplace.json` | `claude-plugins/<p>/` | `.claude-plugin/plugin.json` |
| Codex | `.agents/plugins/marketplace.json` | `.agents/plugins/plugins/<p>/` | `.codex-plugin/plugin.json` |

자동 동기 메커니즘이 **없다**. 한쪽만 고치면 다른쪽이 stale 가 되고, 다른 머신에서 옛 버전이 깔린다 (실측 사고: herdr 가 codex 에서 0.3.0 으로 멈춰 있었음).

- **플러그인 내용(SKILL/스크립트/매니페스트)을 바꿨으면 양쪽 트리를 함께 갱신하고, 두 plugin.json 의 `version` 을 함께 bump 한다.** 한쪽만 bump 금지.
- **SKILL 내용은 맹목 복사 금지.** 일부는 플랫폼별로 *의도적으로* 다르다 (예: codex 는 `bin/` wrapper 경로 해석 블록이 따로 있음). 의미 기준으로 reconcile 하되, 플랫폼 전용 블록은 보존한다.
- 카탈로그/트리 **비대칭은 의도적일 수 있다** — `hetzner-master`·`research-engine` 은 Claude 에선 URL source, Codex 에선 로컬 트리(또는 URL)일 수 있고, `youtube-shorts-orchestrator` 는 현재 codex 전용이다. 의도/사고 구분은 사람이 판단.
- **push 전 게이트**: `python3 scripts/dual-tree-check.py` 실행 → `OK: 버전 skew 없음` 확인. `FAIL ... SKEW` 가 뜨면 bump 누락이므로 push 금지.

### 소비 머신 등록 모델 (이식성)

- **개발 머신(이 repo 의 working clone 이 있는 곳, 예: m1)** — codex 마켓플레이스를 `source_type=local` 로 두면 working tree 를 라이브로 본다(카탈로그 편집 즉시 반영). 단 `marketplace upgrade` 는 local 에서 no-op 이라, plugin 버전 스냅샷 갱신은 `codex plugin add <p>@gprecious-marketplace` 재설치가 필요하다.
- **소비 전용 머신(working clone 이 없는 곳, 예: m2=qplace-macbookpro)** — `source_type=git`, `https://github.com/gprecious/gprecious-marketplace.git` 로 등록한다. 이쪽은 `codex plugin marketplace upgrade gprecious-marketplace` 로 git pull→갱신이 정상 동작한다. **절대경로 local 핀 금지** (머신마다 경로가 달라 깨짐).

## 절대 금지 사항

- **plugin.json에 없다고 폴더/파일 삭제 금지** - agents, channels 등 핵심 로직 폴더는 plugin.json과 무관하게 존재
- **폴더 구조 변경 시 반드시 사용자 확인** - 삭제/이동/통합 전 명시적 승인 필요

## plugin.json 스키마

**필수 키:**
- `name`, `version`, `description`, `author`

**선택 키:**
- `keywords`, `hooks`, `mcpServers`

**사용하지 말 것 (auto-discovery 사용):**
- `commands` - ./commands/ 폴더 자동 인식
- `agents` - ./agents/ 폴더 자동 인식
- `skills` - ./skills/ 폴더 자동 인식

**허용되지 않는 키:**
- `features`, `requiredEnvVars`, `optionalEnvVars`

## 올바른 plugin.json 예시

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "플러그인 설명",
  "author": {
    "name": "author",
    "email": "author@example.com"
  },
  "keywords": ["keyword1", "keyword2"]
}
```

## 잘못된 예시 (절대 사용 금지)

```json
{
  "commands": "./commands/",
  "skills": "./skills/",
  "agents": "./agents/",
  "agents": [
    {"name": "agent-name", "description": "설명", "prompt": "./agents/agent.md"}
  ]
}
```

## marketplace.json 스키마

**필수 키:**
- `name`, `version`, `description`, `owner`, `plugins`

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "marketplace-name",
  "version": "1.0.0",
  "description": "설명",
  "owner": {
    "name": "owner",
    "email": "owner@example.com"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "description": "설명",
      "source": "./claude-plugins/plugin-name",
      "category": "productivity"
    }
  ]
}
```

### source 형식 2가지

**로컬 폴더 (submodule 또는 일반):**
```json
"source": "./claude-plugins/plugin-name"
```

**외부 git repo (URL):**
```json
"source": {
  "source": "url",
  "url": "https://github.com/owner/repo.git"
}
```

외부 repo 형식은 `claude-plugins/` 폴더에 소스를 두지 않아도 됨. `homepage` 키를 함께 적으면 좋음.

## Plugin 추가 워크플로

**A. 외부 git repo (권장 — 소스 분리, 독립 배포):**
1. 외부 repo 준비 (예: `github.com/<owner>/<plugin>.git`)
2. `marketplace.json` `plugins[]` 에 URL source 형식 entry 추가
3. `version` bump (semver — plugin 추가는 minor)
4. commit + push

**B. 로컬 submodule (이 repo 와 라이프사이클 묶고 싶을 때):**
1. `git submodule add <url> claude-plugins/<name>`
2. `marketplace.json` 에 `./claude-plugins/<name>` source 로 등록
3. `version` bump + commit + **push (origin main)**

**C. 로컬 일반 폴더 (이 repo 안에서 직접 개발):**
1. `claude-plugins/<name>/` 디렉토리 생성, `.claude-plugin/plugin.json` 작성
2. `marketplace.json` 등록 + version bump + commit + **push (origin main)**

## Plugin 제거 워크플로

**Submodule 인 경우:**
```bash
git submodule deinit -f claude-plugins/<name>
git rm -f claude-plugins/<name>
rm -rf .git/modules/claude-plugins/<name>
```

**일반 폴더:**
```bash
git rm -rf claude-plugins/<name>
```

**공통:**
1. `marketplace.json` 에서 entry 삭제 + `version` bump
2. `.gitmodules` 자동 정리 확인 (submodule 였을 경우)
3. `README.md` 동기화 (plugin 표에서도 제거)
4. commit + push

## 버전 정책

`marketplace.json` 의 `version` 은 semver:
- **major** — schema 변경, 호환성 깨짐
- **minor** — plugin 추가/제거
- **patch** — description/메타데이터 수정, source 경로 수정

## README.md 동기화

`marketplace.json` 변경 시 `README.md` 의 plugin 표·설치 명령도 함께 업데이트. 두 파일이 다르면 사용자가 어느 쪽을 믿을지 모름. 업데이트 후 commit + **push (origin main)** 까지 — push 안 하면 다른 머신에 안 반영됨 (위 "원격 동기화" HARD RULE).

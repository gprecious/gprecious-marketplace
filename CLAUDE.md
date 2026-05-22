# Claude Code Plugin 개발 규칙

이 repo 는 **gprecious-marketplace** — Claude Code / OpenCode plugin marketplace.
단일 진실 공급원은 `./.claude-plugin/marketplace.json`.

## 폴더 구조

```
gprecious-marketplace/
├── .claude-plugin/
│   └── marketplace.json     # marketplace 카탈로그 (SoT)
├── claude-plugins/          # Claude Code plugin 소스 (로컬 폴더 또는 submodule)
├── opencode-plugins/        # OpenCode plugin 소스
└── README.md                # 사용자용 안내 (marketplace.json 변경 시 동기화 필요)
```

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
3. `version` bump + commit

**C. 로컬 일반 폴더 (이 repo 안에서 직접 개발):**
1. `claude-plugins/<name>/` 디렉토리 생성, `.claude-plugin/plugin.json` 작성
2. `marketplace.json` 등록 + version bump + commit

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

`marketplace.json` 변경 시 `README.md` 의 plugin 표·설치 명령도 함께 업데이트. 두 파일이 다르면 사용자가 어느 쪽을 믿을지 모름.

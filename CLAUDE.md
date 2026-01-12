# Claude Code Plugin 개발 규칙

## 절대 금지 사항

- **submodule 삭제 금지** - `plugins/` 하위 폴더가 비어보여도 submodule일 수 있음. 절대 삭제하지 말 것
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
      "source": "./plugins/plugin-name",
      "category": "productivity"
    }
  ]
}
```

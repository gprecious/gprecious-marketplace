# Claude Code Plugin 개발 규칙

## 절대 금지 사항

- **plugin.json에 없다고 폴더/파일 삭제 금지** - agents, channels 등 핵심 로직 폴더는 plugin.json과 무관하게 존재
- **폴더 구조 변경 시 반드시 사용자 확인** - 삭제/이동/통합 전 명시적 승인 필요

## plugin.json 스키마

**허용되는 키:**
- `name`, `version`, `description`, `author`, `keywords`
- `commands` → 디렉토리 경로 (예: `"./commands/"`)
- `agents` → 디렉토리 경로 (예: `"./agents/"`) - auto-discovery 사용
- `skills` → 디렉토리 경로 (예: `"./skills/"`)
- `hooks`, `mcpServers`, `outputStyles`, `lspServers`

**허용되지 않는 키:**
- `features`, `requiredEnvVars`, `optionalEnvVars`

**agents 올바른 형식:**
```json
{
  "agents": "./agents/"
}
```
또는 여러 디렉토리:
```json
{
  "agents": ["./agents", "./specialized-agents"]
}
```

**agents 잘못된 형식:**
```json
{
  "agents": [
    {"name": "agent-name", "description": "설명", "prompt": "./agents/agent-name.md"}
  ]
}
```

# Claude Code Plugin 개발 규칙

## plugin.json 스키마

**허용되는 키:**
- `name`, `version`, `description`, `author`, `keywords`
- `commands` → 디렉토리 경로 (예: `"./commands/"`)
- `agents` → **객체 배열** (name, description, prompt 필드 필수)
- `skills` → 디렉토리 경로 (예: `"./skills/"`)
- `hooks`, `mcpServers`, `outputStyles`, `lspServers`

**허용되지 않는 키:**
- `features`, `requiredEnvVars`, `optionalEnvVars`

**agents 올바른 형식:**
```json
{
  "agents": [
    {"name": "agent-name", "description": "설명", "prompt": "./agents/agent-name.md"}
  ]
}
```

**agents 잘못된 형식:**
```json
{
  "agents": "./agents/",
  "agents": ["agent1", "agent2"]
}
```

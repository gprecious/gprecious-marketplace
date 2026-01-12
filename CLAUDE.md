# Claude Code Plugin 개발 규칙

## plugin.json 스키마

**허용되는 키:**
- `name`, `version`, `description`, `author`, `keywords`
- `commands`, `agents`, `skills` → **디렉토리 경로** (예: `"./agents/"`)
- `hooks`, `mcpServers`, `outputStyles`, `lspServers`

**허용되지 않는 키:**
- `features`, `requiredEnvVars`, `optionalEnvVars`

**올바른 예시:**
```json
{
  "commands": "./commands/",
  "agents": "./agents/",
  "skills": "./skills/"
}
```

**잘못된 예시:**
```json
{
  "commands": [{ "name": "foo", "description": "..." }],
  "agents": ["agent1", "agent2"]
}
```

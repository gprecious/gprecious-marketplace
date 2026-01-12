---
name: shorts
description: YouTube Shorts 영상 제작 (→ /shorts 명령어 사용)
command: /shorts
agents:
  - main-orchestrator
---

# /shorts Skill

YouTube Shorts 영상 제작 스킬입니다.

## 사용 방법

```bash
/shorts [옵션]
```

> **상세 문서**:
> - 사용법: `commands/shorts.md`
> - 워크플로우: `agents/main-orchestrator.md`

## 실행

이 스킬은 `main-orchestrator` 에이전트를 호출합니다.

```
Task(main-orchestrator, prompt="{user_input}")
```

main-orchestrator가 전체 파이프라인을 지휘하며,
모든 서브에이전트를 위임 호출합니다.

# DevSweep M7 — Git Worktree Detector 설계

**상태:** 설계 승인됨 (2026-06-11). 다음 단계: writing-plans.
**선행:** M1~M6 완료 (main). 이 문서는 M2 detector 아키텍처(`docs/superpowers/specs/2026-06-09-devsweep-m2-detectors-design.md`) 위에 4번째 `CleanupModule`을 얹는다.

---

## 1. 동기 / 문제

DevSweep의 현재 detector 3종(Docker / PackageCache / NodeModules)은 **git worktree를 "정리 단위"로 인식하지 못한다.** 개발자가 worktree를 자주 만들고(이 프로젝트는 herdr 병렬 패턴으로 `<repo>/.worktrees/<name>`에 worktree를 생성) 머지 후 `git worktree remove`를 깜빡하면, 잊힌 worktree가 디스크를 잠식한다.

**실측 (2026-06-11, 개발 머신):** 한 사내 repo의 `.worktrees/<feature>` worktree — **2.2GB**, 10일 stale, clean, `origin`에 푸시됨, main 미머지. 현재 DevSweep은 이 worktree를 단위로 못 잡고, 그 안 node_modules 일부만 review 후보로 띄울 뿐이며 — worktree의 중복 체크아웃 소스 + 빌드 산출물은 회수 불가다.

worktree를 단위로 회수하면 그 안의 node_modules·build 산출물·중복 소스가 **한 번에** 회수된다(핵심 이득). 동시에 git 상태를 바꾸는 동작이라 **데이터 손실 방지**가 최우선이다.

## 2. 범위 결정 (사용자 승인)

1. **정리 대상 = 머지+clean (+ orphan 잔재 prune)** — "stale 미머지(미푸시)"나 "머지된 로컬 브랜치 삭제"는 범위 밖.
2. **안전 후보 기준 = clean + unlocked + 로컬 전용 커밋 0** (모든 커밋이 origin에 푸시됐거나 main에 머지됨). **미푸시 로컬 커밋이 1개라도 있으면 `.protected`.** → main 미머지여도 origin에 있으면 재checkout 가능 → 데이터 손실 0. 실측 2.2GB worktree를 안전하게 회수.

비범위(후속/YAGNI): 머지된 로컬 브랜치(`git branch -d`) 정리, stale 미푸시 worktree, bare 클론 정리, `--force` 제거.

## 3. 아키텍처 — 새 1급 `WorktreeModule`

기존 `CleanupModule` 계약(`id`/`displayName`/`isAvailable`/`scan`/`reclaim`)을 구현하는 **CLI-reclaim 모듈**. Docker 모듈과 동렬·동일 패턴(자기 도구의 state-aware 명령으로 회수 + before/after 실측). path-기반 M1 Reclaimer 경유가 아니라 `git worktree remove`로 회수한다 — 이는 `rm -rf`보다 안전(아래 §6 방어선).

- `id = "git-worktrees"`, `displayName = "Git Worktrees"`
- 의존성: `CommandRunner`(git 호출), `DirectorySizer`(du), 활성검사용 `ProcessReferenceSignal`(M1 재사용), git executable(기본 `/usr/bin/env git`)
- `DefaultDetectorRegistry.makeModules(...)`의 반환 배열에 4번째로 추가. `devRoots`를 공유.

## 4. 탐지 (`scan()`, read-only)

1. `devRoots`(기본 `~/Documents/dev`) 아래에서 **메인 repo**(`.git` *디렉토리* 보유)를 찾는다. bounded(maxDepth, 예: 4). symlink 미추적.
2. 각 메인 repo에서 `git -C <repo> worktree list --porcelain` 실행. git이 권위적 목록 + 플래그 제공:
   - 각 항목: `worktree <path>` / `HEAD <sha>` / `branch <ref>` 또는 `detached` / `locked [reason]` / `prunable [reason]`
   - **첫 항목 = 메인 working tree → 항상 skip** (정리 대상 아님).
   - `.worktrees/` 중첩이든 `/tmp/wt-*`든 git이 위치 무관하게 다 나열 → 파일시스템 `.git`-파일 스캔보다 견고. `locked`/`prunable`을 공짜로 얻음.
3. 메인 repo의 default 브랜치 = `git symbolic-ref --short refs/remotes/origin/HEAD`(없으면 현재 HEAD)로 1회 확인.

## 5. 분류 (안전 두뇌) — 데이터 손실 0 게이트

각 링크된 worktree를 다음 순서로 평가. 하나라도 protected 조건이면 즉시 `.protected`:

| # | 조건 | 판정 |
|---|---|---|
| 0 | 메인 working tree (porcelain 첫 항목) | **대상 아님** (skip) |
| 1 | `locked` (사용자 명시 잠금) | `.protected` |
| 2 | dirty — `git -C <wt> status --porcelain` 비어있지 않음 (uncommitted/untracked) | `.protected` |
| 3 | **로컬 전용 커밋 존재** — `git -C <repo> rev-list <HEAD> --not --remotes <default>` 비어있지 않음 | `.protected` |
| 4 | 활성 — worktree 경로를 참조하는 실행 중 프로세스 (`ProcessReferenceSignal`) | `.protected` |
| 5 | 위 전부 통과 = clean + unlocked + 전부 푸시/머지 + 비활성 | **`.reviewNeeded`** |
| 6 | `prunable` (작업 dir 사라진 admin 잔재) | 별도 orphan 항목 (§7) |

- **§5.3 정밀 정의 (데이터 손실 0의 핵심):** worktree HEAD에서 도달 가능한 커밋 중 **모든 remote-tracking ref(`--remotes`)와 default 브랜치 어디에도 없는** 커밋이 하나라도 있으면 = 로컬 전용 작업 존재 → protected. 비어 있으면 = 모든 작업이 origin에 있거나 머지됨 → 제거해도 재checkout 가능 → 후보. detached HEAD worktree도 동일(HEAD sha 기준).
- **§5.5 후보 메타:** `sizeBytes` = `DirectorySizer`의 worktree dir du. `lastUsed` = 마지막 커밋 시각. 라벨(표시용, 게이트 아님):
  - `merged` = ancestor-merged(`git branch --merged <default>`) **OR** content-diff empty(`git diff --quiet <default>...<branch>`) **OR** upstream-gone(`status -sb`에 `gone]` — PR 머지 후 원격 브랜치 삭제).
  - 위 셋 다 아니지만 게이트 통과(푸시됨) → `pushed·unmerged`.
- `.autoSafe`는 **절대 사용 안 함** — 모든 worktree 후보는 `.reviewNeeded`(자동삭제 없음).

## 6. 회수 (`reclaim(items, dryRun)`)

Docker `reclaim()` 패턴 미러:

1. `item.reclaimMethod`가 `.cliCommand`인지 가드. 아니면 `.failed`.
2. **인자에 `--force`가 있으면 거부**(`.failed`) — 불변식.
3. `dryRun` → `.dryRun(plannedBytes: item.sizeBytes)`, 부작용 0.
4. 실제: `before = DirectorySizer.size(worktreePath)` → `git -C <mainRepo> worktree remove <path>` 실행(**`--force` 없이**) → exitCode 0 + 경로 소멸 확인 → `.deleted(bytes: before)`. exit≠0 또는 경로 잔존 → `.failed(message:)`.
5. orphan 항목(§7) → `git -C <mainRepo> worktree prune` → `.deleted(bytes: 0)`(tidiness).
6. **브랜치 ref는 건드리지 않는다** (Q1 범위 — 푸시/머지돼 있어 보존).

`reclaimMethod = .cliCommand(executable: "/usr/bin/env", arguments: ["git", "-C", <mainRepo>, "worktree", "remove", <path>])`.

**`--force` 미사용이 2차 방어선:** plain `git worktree remove`는 worktree가 dirty거나 변경된 submodule이 있으면 **거부**한다. §5 분류에 버그가 생겨 dirty가 새어 들어와도 git이 막아준다(rm -rf엔 없는 안전망).

## 7. orphan / prunable 잔재

`prunable` 플래그가 붙은 항목(작업 dir이 이미 삭제됐는데 `.git/worktrees/<name>` admin만 잔존)은 디스크 절약 ≈0(admin 파일뿐)이지만 worktree list를 더럽힌다. → repo당 1개의 합산 항목 "N orphan worktree entries" (`sizeBytes: 0`, `.reviewNeeded`)로 노출, 회수 = `git worktree prune`. 부차 기능(없어도 핵심 가치 유지).

## 8. NodeModules 이중계산 제거 (집계 단계)

worktree는 보통 `<repo>/.worktrees/...`에 있고 `NodeModulesModule`이 그 하위 node_modules를 **또** 잡아 같은 바이트가 두 모듈에 중복 집계된다.

**해법 = 집계 단계의 모듈-무관 중첩 억제 규칙:** 스캔 결과 합산 시, 어떤 항목 `A`(worktree)의 `path`가 다른 path-기반 항목 `B`(node_modules 등)의 prefix이면 `B`를 제거한다(worktree가 단위로 흡수). worktree 경로를 NodeModulesModule에 주입하는 대안보다 단순하고(모듈은 독립·병렬 스캔 유지) 일반적이다.

- 구현 위치: `DetectorRegistry.scanGrouped` 또는 AppCoordinator의 결과 합산부에 순수 함수 `suppressNested(items:)` 추가. 경로 정규화(trailing slash, `..` 제거) 후 prefix 비교.
- 회수 라우팅도 동일 권위(grouped module id) 유지 — M4 교훈(`ReclaimRouter.reclaim(grouped:)`)과 일관.

## 9. 안전 / M1 인프라 재사용

- 활성검사(§5.4)는 M1 `ProcessReferenceSignal`을 worktree 경로에 적용(실행 중 dev 서버·셸 cwd가 worktree 안이면 protect). launchd/crontab 신호는 worktree에 거의 무의미하므로 선택(YAGNI — 1차는 process만).
- recency(마지막 커밋/파일 mtime)는 **하드 게이트 아님** — 표시용. 최근 커밋이어도 푸시됐으면 안전. (선택: 표시 정렬/필터에만 사용.)
- worktree 회수는 M1 Reclaimer를 경유하지 않는다(CLI-reclaim 예외, Docker와 동일). 단 "경로 삭제는 Reclaimer 경유" 불변식과 충돌 아님 — `git worktree remove`는 path-delete가 아니라 도구의 state-aware 명령(불변식 문서에 명시).

## 10. 불변식 (회귀 방지)

1. worktree 회수는 **항상 `git worktree remove`(no `--force`)** — raw `rm`/`deletePath` 금지.
2. dirty / 로컬 전용 커밋 / locked / 활성 중 하나라도면 무조건 `.protected`. worktree 후보는 전부 `.reviewNeeded` — `.autoSafe` 금지(자동삭제 없음).
3. **메인 working tree는 어떤 경우에도 대상 아님.**
4. 중첩 억제로 worktree↔node_modules 이중계산 금지.
5. 브랜치 ref 삭제 금지.

## 11. 엣지 케이스

- default 브랜치 미상(origin/HEAD 없음): 현재 HEAD를 default로 사용, `--not --remotes`만으로 게이트(머지 라벨은 보수적으로 미표시).
- detached HEAD worktree: branch 없음 → HEAD sha 기준 게이트(§5.3), 라벨 `pushed·unmerged` 또는 `merged`만.
- bare 메인 repo: porcelain에 `bare` → 메인 항목 skip 동일.
- worktree 경로가 devRoots 밖(`/tmp/wt-*`): 메인 repo가 devRoots 안이면 git이 나열 → 회수됨. 메인 repo 자체가 devRoots 밖이면 미발견(범위 밖, 허용).
- git 미설치/오류: `isAvailable()`=false → 레지스트리가 모듈 숨김.
- 매우 큰 worktree du: `DirectorySizer`가 bounded(M4 du 경험 — off-main 보장은 AppCoordinator 책임).

## 12. 테스트 (TDD — M1/M2처럼 herdr 3단계 가능)

임시 git repo + `git worktree add` 픽스처(CommandRunner는 실 git 또는 mock). 핵심 케이스:

1. clean + ancestor-merged → 후보(`merged`).
2. clean + 푸시·미머지(origin에 있음) → 후보(`pushed·unmerged`). ← 실측 2.2GB 시나리오.
3. **clean + 미푸시 로컬 커밋 1개 → `.protected`.** ← 데이터 손실 0 핵심 회귀.
4. dirty(uncommitted) → `.protected`.
5. dirty(untracked만) → `.protected`.
6. `locked` worktree → `.protected`.
7. 활성 프로세스가 경로 참조 → `.protected`.
8. 메인 working tree → 후보에서 제외.
9. 중첩 node_modules 항목 → 집계서 억제(이중계산 0).
10. `prunable` orphan → orphan 항목 + `prune` 회수.
11. reclaim: `git worktree remove` no-`--force`가 dirty를 거부(방어선) → `.failed`, worktree 잔존.
12. reclaim dryRun → 부작용 0, `.dryRun(plannedBytes:)`.
13. reclaim 성공 → 경로 소멸 + `.deleted(bytes: du)`.
14. `--force` 포함 명령 → 거부(`.failed`).

빌드: Swift 6 / macOS 14 / Swift Testing. DevSweepCore에 모듈·순수 분류 로직(테스트 가능), CommandRunner 추상화로 git 호출 mock.

## 13. 비범위 (후속)

- 머지된 로컬 브랜치 정리(`git branch -d`).
- stale 미푸시 worktree(데이터 손실 위험 — 경고付 review 등급).
- worktree별 라이브 프리뷰/점진 sizing.
- launchd/crontab 활성신호(worktree엔 무의미).
- UI 세부(MenuView "Git Worktrees" 그룹)는 기존 모듈 표시 패턴 그대로 따름 — 별도 설계 불필요.

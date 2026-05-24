---
name: hetzner-proxmox-deploy
description: Use when deploying or operating workloads on the hetzner-master Proxmox lab (single Hetzner box at 195.201.80.242, Proxmox VE 8 + ZFS + Tailscale subnet router) — adding LXC containers, integrating with the Prometheus/Grafana stack, exposing services through the firewall, or troubleshooting infrastructure issues specific to this lab
---

# hetzner-proxmox-deploy

이 skill은 **`hetzner-master` 레포가 관리하는 단일 Hetzner Proxmox 박스**에 워크로드를 배포·운영할 때 사용한다. 다른 Proxmox 클러스터에는 적용되지 않음 (네트워크 가정/IP 대역/access pattern 모두 이 박스에 종속).

## 한 줄 컨텍스트

- **호스트**: `pve-master` (195.201.80.242), Proxmox VE 8.4, ZFS mirror data pool 378GB
- **내부 네트워크**: vmbr1 = 10.10.10.0/24 NAT, gateway 10.10.10.1 (호스트)
- **외부 접근**: Tailscale subnet router (CT 100, 10.10.10.10) 경유 → Mac에서 10.10.10.x 직접 도달
- **모니터링**: CT 101 monitor (10.10.10.20) — Prometheus + Grafana + Alertmanager + node_exporter (모든 LXC 자동 스크레이프)
- **방화벽**: 외부 ingress = ICMP + Tailscale UDP 41641만, 내부는 Tailnet 100.64.0.0/10만
- **IaC 레이어**: bootstrap shell (`bootstrap/`) → terraform `bpg/proxmox` (`terraform/`) → ansible roles (`ansible/`) → bats smoke tests (`tests/smoke/`)

## When to Use This Skill

- 새 LXC 워크로드 컨테이너를 추가하고 싶을 때
- PostgreSQL 관리형 appliance instance 를 생성하거나 운영하고 싶을 때
- 기존 워크로드의 모니터링/알림을 셋업할 때
- Mac/외부에서 새 서비스에 접근할 수 있게 방화벽을 조정할 때
- 호스트 또는 컨테이너에서 네트워크/스토리지/Tailscale 관련 문제를 진단할 때
- 인프라 정기 점검 (백업, 키 회전, Proxmox 업그레이드)

## When NOT to Use

- 다른 Hetzner 박스 / 다른 Proxmox 클러스터 → 이 skill의 IP/패턴 가정 안 맞음. `bootstrap/`을 처음부터 다시 돌릴 것
- 단순 Proxmox UI 클릭 작업 → IaC drift 만듦. 항상 terraform/ansible 통해서 변경
- 1회성 디버깅 SSH → 그냥 `just ssh-host` 후 작업, skill 불필요

## 작업 라우팅 (어느 reference를 읽을지)

| 의도 | reference 파일 |
|------|---------------|
| 인프라 전체 구성/IP/네트워크 토폴로지 파악 | [`references/01-architecture.md`](references/01-architecture.md) |
| 신규 워크로드 컨테이너 추가 (end-to-end) | [`references/02-deploy-workload.md`](references/02-deploy-workload.md) |
| Prometheus 타깃 추가, Grafana 대시보드, Alertmanager 룰 | [`references/03-monitoring.md`](references/03-monitoring.md) |
| 방화벽 규칙, 서비스 노출 (Tailnet/public), bridge 함정 | [`references/04-firewall-and-access.md`](references/04-firewall-and-access.md) |
| 복사용 코드 템플릿 (terraform/ansible/bats) | [`references/05-templates.md`](references/05-templates.md) |
| 함정 모음 + 진단 명령 | [`references/06-troubleshooting.md`](references/06-troubleshooting.md) |
| 백업, 업그레이드, 키 회전, 정기 운영 | [`references/07-operations.md`](references/07-operations.md) |
| PostgreSQL managed appliance instance 생성/운영 | [`references/08-postgres-managed-appliance.md`](references/08-postgres-managed-appliance.md) |
| **운영 평면(CT 150 ops) 이해 — PG/Redis/Caddy/web-app/worker 단일 LXC** | [`references/09-ops-plane.md`](references/09-ops-plane.md) |

**처음 진입할 때**: 01 → (목적별 02~04 또는 08) → 05 (실제 작성) → 06 (막히면). 사업 로직(인증/결제/사이트)을 만지러 왔다면 09 부터. 한 번에 다 읽지 말 것.

## 사전 조건 (Mac에서)

```bash
# 1. 도구
brew install just terraform ansible bats-core jq tailscale

# 2. SSH 키 (Hetzner에 등록된 키)
ls -1 ~/.ssh/hetzner_pve     # private key 존재 확인

# 3. Tailscale 로그인 + ts-router 라우트 승인 확인
tailscale status | grep ts-router

# 4. Proxmox API 토큰 (terraform용)
test -f secrets/proxmox-api.env && source secrets/proxmox-api.env
echo "$PROXMOX_VE_ENDPOINT"   # https://195.201.80.242:8006/

# 5. 레포 루트로 이동
cd <hetzner-master 레포 경로>
```

### CT 130 `agent-host` 에서 실행할 때

`agent-host` 의 checkout 은 Mac checkout 과 gitignored `secrets/` 상태가 다를 수 있다. LXC 배포/변경을 CT 130에서 수행한다면, Terraform 전에 반드시 아래 preflight 를 먼저 통과시킨다:

```bash
test -f secrets/proxmox-api.env
tailscale ping -c 1 10.10.10.1
```

이후 raw `terraform plan/apply` 대신 `just tf-plan` / `just tf-apply` 를 사용한다. `Justfile` 이 `secrets/proxmox-api.env` 를 source 하기 때문이다. 파일이 없거나 토큰이 stale 해서 401/permission denied 가 나면 토큰을 추측·재발급하지 말고 사용자에게 provisioning 을 요청한다.

## Terraform state safety (HARD GATE)

현재 state는 remote backend가 아니라 `terraform/environments/prod/terraform.tfstate` local file이다. 이 파일은 gitignored 이므로 다른 머신/checkout/agent-host가 같은 config를 보더라도 같은 state를 본다는 보장이 없다. 장기 목표는 shared remote backend로 이전하는 것이지만, 그 전까지는 아래 규칙이 canonical이다:

1. raw `terraform plan/apply` 금지. 항상 `just tf-plan` / `just tf-apply`.
2. wrapper는 plan JSON을 검사해서 "live에 이미 존재하는 VMID/CTID를 Terraform이 create하려는" 경우 실패한다.
3. 이 실패는 stop condition이다. guard를 우회하지 말고 live 리소스를 state에 import 하거나 stale config를 제거한다.
4. live CT/VM을 IaC에 흡수하는 경우에는 먼저 state 백업 → `terraform import '<resource address>' pve-master/<vmid>` → `just tf-plan` clean 확인 순서로 진행한다.
5. 새 workload는 baseline `just tf-plan` 이 기존 fleet에 대해 clean 한 상태에서만 추가한다.

자세한 incident 기록: `docs/wisdom/07-terraform-state-split-brain.md`.

## 핵심 명령 (Quick Reference)

| 의도 | 명령 |
|------|------|
| 시스템 상태 확인 | `just status` |
| 모든 smoke test | `just test` |
| Proxmox UI (Tailscale) | `just ui` |
| Grafana | `just grafana` |
| 호스트 SSH | `just ssh-host` |
| terraform plan/apply | `just tf-plan` / `just tf-apply` |
| ansible workloads 적용 | `just ansible-workloads` |
| ansible site (전체) | `just ansible-site` |
| inventory 동기화 | `just inventory-sync` |

## 4가지 안전 원칙

1. **Proxmox UI에서 클릭 금지**. 컨테이너 생성/삭제/리소스 변경은 항상 terraform. UI 클릭은 IaC drift 만듦.
2. **모든 컨테이너는 `vmbr1` (10.10.10.0/24)**. 직접 vmbr0 (public)에 붙이지 말 것 — 호스트 firewall이 보호 못 함.
3. **공개 인터넷에 직접 노출 금지**가 기본. 새 서비스는 Tailnet에서만 접근. public 노출이 필요하면 [`04-firewall-and-access.md`](references/04-firewall-and-access.md)의 명시적 절차 따를 것.
4. **destructive 명령 (`pct destroy`, `terraform destroy`, `zpool destroy`)은 사용자 확인 후만 실행**. 이 skill의 규칙이 아니라 cmux/orchestrator 정책.

## 변경 후 검증 (HARD GATE)

워크로드를 추가/수정한 뒤에는 **반드시** 아래 셋 다 통과해야 "완료" 라고 보고할 수 있다:

```bash
# 1) 라이브 검증
just test                                # 21+ bats 테스트 PASS
just ssh-host 'pct list'                 # 새 컨테이너 running 상태 확인

# 2) IaC 동기화 — 변경된 terraform/ansible/tests 파일을 repo 에 영구화
git status                               # 빠진 파일 없는지
git diff --stat                          # 의도한 변경만 들어갔는지
git add <files> && git commit -m "<scope>: <intent>"
git push                                 # origin/main 까지 도달해야 다른 운영자(미래의 나)도 같은 상태에서 출발
```

UI를 노출했다면 추가로:

```bash
# Tailscale 경로로 실제 접근 (브라우저 또는 curl)
curl -fsS http://10.10.10.<new-ct-ip>:<port>/ | head -5
```

**왜 push 까지 강제하나**: 라이브는 바뀌었는데 repo 가 안 바뀌면 다음 `terraform plan` 이 "라이브가 drift 했다" 고 오판하고, `01-architecture.md` 의 좌표화/예약 체계 (`.coordination/active.md` + pre-commit hook) 가 우회된다. 로컬 commit 만 하고 push 안 하면 다른 머신/세션이 같은 CTID·IP 를 재사용해서 충돌 (incident: 2026-05-18 CT 150).

통과 못 하면 `06-troubleshooting.md` 부터 읽기. push 가 막히면 (pre-commit hook 거부 등) `01-architecture.md` 의 좌표화 섹션 참조.

## Red Flags — STOP

다음 신호 보이면 작업 멈추고 사용자에게 보고:

- "그냥 UI에서 만들면 안 될까" → 안 됨. terraform 통해서만.
- "방화벽 잠시 풀고 진행" → 절대 금지. 필요하면 `04`의 명시적 expose 절차.
- "ZFS 풀 다시 만들면 빠르겠다" → 데이터 손실 위험. zpool destroy는 사용자 확인 후.
- "테스트 실패하지만 그냥 보고하자" → 실패는 곧 미완성. 06 읽고 디버깅.
- "Proxmox 엔터프라이즈 repo 나오는데 무시" → `bootstrap/05`가 자동 제거. 안 되면 docs/wisdom #6.

## 운영 메타

- **레포 경로**: 이 skill은 `<repo>/skills/hetzner-proxmox-deploy/`. 레포가 옮겨지면 `install.sh` 재실행.
- **Wisdom 누적**: 새 함정/결정은 `docs/wisdom/` 에 추가하고, 자주 나오면 이 skill의 06/02로 승격.
- **Codex 호환**: SKILL.md frontmatter는 Codex와 Claude Code 양쪽 표준. references/는 둘 다 동일하게 follow.

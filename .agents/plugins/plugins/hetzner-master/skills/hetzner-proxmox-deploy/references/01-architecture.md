# 01 — Architecture

`hetzner-master` 단일 박스 Proxmox 랩의 물리/논리 구성. 이 문서는 **사실 매핑** — IP, ID, 토폴로지. 의사결정 배경은 `docs/wisdom/02-architecture-decisions.md`.

## 하드웨어 (Hetzner Server Auction #2990542)

| 항목 | 값 |
|------|----|
| CPU | Intel Xeon E3-1275v6 (4 core / 8 thread) |
| RAM | 64 GB DDR4 ECC |
| 디스크 | 2× 480 GB SATA SSD (mdadm RAID1 + ZFS mirror 분리) |
| 위치 | 핀란드 Helsinki (hel1) |
| Public IPv4 | 195.201.80.242 |
| Public IPv6 | 2a01:4f8:13b:149::/64 (호스트는 ::2) |
| 게이트웨이 | 195.201.80.225 (Hetzner /27 subnet) |

## OS / 가상화 스택

```
┌──────────────────────────────────────────────────────┐
│ Debian 12 Bookworm + Proxmox VE 8.4.19               │
│ kernel 6.8.12-23-pve                                 │
│                                                      │
│ Storage:                                             │
│   /boot  (mdadm RAID1, ext3, 1G)                     │
│   swap   (mdadm RAID1, 4G)                           │
│   /      (mdadm RAID1, ext4, 64G)                    │
│   data   (ZFS mirror sda4+sdb4, ~378G)               │
│     ├─ data/vm   (mountpoint=/data/vm,  for VMs)    │
│     └─ data/lxc  (mountpoint=/data/lxc, for CTs)    │
│   ZFS ARC capped at 8 GiB                            │
└──────────────────────────────────────────────────────┘
```

## 네트워크 토폴로지

```
                          ╔════════ Hetzner /27 ════════╗
                          ║  195.201.80.224/27          ║
                          ║  gateway 195.201.80.225     ║
                          ╚═════════════╤═══════════════╝
                                        │ enp4s0 (physical NIC)
                                        │
                  ┌─────────────────────┴────────────────────────┐
                  │ vmbr0 (public)                               │
                  │   - 195.201.80.242/32 (host)                 │
                  │   - pointopoint route to gateway             │
                  │   - additional Hetzner IPs routed here as /32│
                  └────────────────────────────────────────────┬─┘
                                                               │ MASQUERADE
                                                               │ (NAT outbound)
┌────────────── Tailnet (100.64.0.0/10) ──────────────┐        │
│                                                     │        │
│  Mac (your laptop) ──────────────┐                  │        │
│                                  │                  │        │
│  CT 100 ts-router (100.84.237.9) │                  │        │
│   - subnet route 10.10.10.0/24   │                  │        │
│   - --ssh enabled                │                  │        │
│                                  │                  │        │
└──────────────────────────────────┼──────────────────┘        │
                                   │                           │
                                   ▼                           │
            ┌─────── vmbr1 (internal NAT bridge) ──────────────┴─┐
            │  10.10.10.0/24                                      │
            │  gateway 10.10.10.1 (host)                          │
            │                                                     │
            │  CT 100 ts-router          → 10.10.10.10 (Tailscale)│
            │  CT 101 monitor            → 10.10.10.20 (Prom/Graf)│
            │  CT 109 ingress (Caddy)    → 10.10.10.5             │
            │     ↑ host iptables PREROUTING :80/:443 → here      │
            │  CT 110 officetel-analyzer → 10.10.10.30 (Docker)   │
            │  CT 150 ops                → 10.10.10.50            │
            │     (PG 16 / Redis 7 / Caddy / web-app / worker)    │
            └─────────────────────────────────────────────────────┘
```

핵심 사실:
- **vmbr0는 public, vmbr1은 사설 NAT**. 워크로드는 거의 항상 vmbr1.
- **Hetzner는 same-subnet ARP 차단** → 추가 IP는 모두 `/32` + pointopoint 라우팅. (`bootstrap/04-network-config.sh`)
- **vmbr1 컨테이너의 outbound**는 호스트 MASQUERADE를 거쳐 vmbr0으로 나간다.
- **bridge-nf-call=0** (sysctl로 설정) — vmbr1 내부 LXC↔LXC TCP가 호스트 iptables 거치지 않음. 이거 안 하면 UFW가 default-deny FORWARD로 SYN drop. (`docs/wisdom #16`)

## IP 할당 규약

| 대역 | 용도 |
|------|------|
| 10.10.10.1 | 호스트 (vmbr1 gateway) |
| 10.10.10.5 | CT 109 ingress (Caddy, 공개 :80/:443 단일 진입점) |
| 10.10.10.10 | CT 100 ts-router (Tailscale) |
| 10.10.10.20 | CT 101 monitor (Prom/Grafana) |
| 10.10.10.30–10.10.10.49 | 일반 워크로드 (CT 110 officetel-analyzer 가 .30 사용 중) |
| 10.10.10.50 | CT 150 ops (운영 평면 — PG/Redis/Caddy/web-app/worker) |
| 10.10.10.51–10.10.10.99 | 일반 워크로드 (시간순 할당) |
| 10.10.10.100–10.10.10.199 | DB / stateful 서비스, PostgreSQL appliance support |
| 10.10.10.200–10.10.10.254 | 임시/실험 |

CTID 규약:
- 100~109 — 인프라 (ts-router, monitor, ingress)
- 110~149 — 일반 워크로드 (시간순)
- 150 — 운영 평면 (`ops` CT — 사업 전체 stateful 서비스 단일 LXC)
- 151~199 — 사이트 LXC (W3+에서 per-site 자동 생성 예정)
- 200~ — 임시/실험 (절대 prod 워크로드 두지 말 것 — W1 에서 CT 200 가 IP 충돌로 사장된 사례 있음, `docs/ops-w1-bootstrap.md`)

예약:
- CT 170 `postgres-backup-relay` → 10.10.10.105 (shared PostgreSQL appliance backup relay)
- VM 171 `shared-postgres-prod-primary` → 10.10.10.110
- VM 172 `shared-postgres-prod-standby` → 10.10.10.111
- CT 173 `shared-postgres-prod-router` → 10.10.10.112

## RESERVATION RULE — 새 ID 를 doc 에 예약하기 전 필수 검증

문서상 "예약" 만으로는 충돌을 막지 못한다. UI 클릭이나 수동 `pct create` 로 TF 밖에서 만들어진 컨테이너가 있을 수 있기 때문이다 (incident: 2026-05-18 CT 150). 새 CTID/VMID/IP 를 위 예약 목록에 추가할 때마다 세 가지를 확인하고, 그 결과를 PR/commit 메시지에 남긴다.

### 1) 실측 — 호스트가 모르는 자원이 없는지

```bash
ssh root@10.10.10.1 'pct list; qm list'
```

위 출력에 있는데 `terraform/environments/prod/main.tf` 에 없는 CTID/VMID 가 **"TF drift"** 다. 그 ID 위에 새 예약을 올리면 충돌이 보장된다. 한 발 빠른 방법: `just check-drift` 로 차이만 출력.

### 2) IP 응답성 — 후보 IP 들

```bash
ssh root@10.10.10.1 'for ip in <후보들>; do ping -W 1 -c 1 10.10.10.$ip >/dev/null && echo "$ip USED" || echo "$ip free"; done'
```

`USED` 가 나오면 그 IP 자리에 LXC/VM 이 이미 있다 (TF 에 없을 수도 — 1번 검증과 교차 확인).

### 3) Governance test — 예약을 코드로 잠근다

`tests/smoke/04-pools-and-tags.bats` 의 "doc-reserved CTIDs do not collide with TF-drift containers" 테스트가 위 두 검증을 매번 자동화한다. 새 예약을 추가했으면 그 ID 를 테스트의 `RESERVED_IDS` 배열에 추가한다. 기존 drift 와 충돌이 검출되면 그 테스트가 RED 가 되며, 해결되기 전까지는 (a) drift 를 제거하거나 (b) 예약 ID 를 다른 자리로 옮기거나 (c) `KNOWN_UNRESOLVED` 에 등재하고 wisdom doc 으로 사유를 남긴다.

### 4) `.coordination/active.md` 에 의도 선언 + pre-commit hook (강제)

`tests/smoke/...` 는 `just test` 를 돌려야 작동한다. 더 빠른 강제: `.coordination/active.md` 에 작업 시작 시 한 줄 declare (`CT-150 / 10.10.10.50` 같은 자원 명시). `just install-hooks` 로 설치된 `scripts/hooks/pre-commit` 이 commit 단계에서 다음 세 가지를 자동 검출하고 충돌이면 commit 을 거부한다:

1. `terraform/environments/prod/main.tf` 내부 vmid/ipv4 중복
2. 다른 세션이 `active.md` 에서 점유 선언한 자원
3. Proxmox 호스트에 이미 라이브로 존재하는 CTID (TF-drift)

자기 브랜치 entry 는 자기 commit 을 막지 않는다. SSH 도달 불가 시 (3) 만 soft-skip (경고 후 통과), 나머지는 항상 동작. `terraform import` 처럼 의도적으로 라이브 자원을 IaC 에 흡수할 때만 `SKIP_RESERVATION_CHECK=1 git commit ...` 로 우회하고 그 사유를 commit 메시지에 남긴다.

### Drift 발견 시 처리 순서

1. 우리(or 다른 작업자) 가 의도적으로 만든 자원인지 확인
2. 의도적이면 → `terraform import` 로 TF state 흡수 (`02-deploy-workload.md`)
3. 의도적이지 않거나 폐기 가능하면 → 사용자 confirm 후 `pct destroy`
4. 의미 있으나 옮길 수 있으면 → `vzdump` + `pct restore <new-id>` 로 다른 CTID 로 이주
5. **예약 doc 만 수정하지 말 것** — 충돌의 근본은 doc-실측 갭이지, doc 자체가 아님

근거 incident: 2026-05-18 CT 150 충돌 — `docs/wisdom/06-ctid-reservation-discipline.md`.

## 기존 컨테이너

| CTID | hostname | IP | OS | Memory | 역할 |
|------|----------|-----|----|--------|------|
| 100 | ts-router | 10.10.10.10 | Debian 12 | 256MB | Tailscale subnet router. Bootstrap-managed by `bootstrap/06-tailscale-router-lxc.sh`; intentionally not imported into Terraform because it is the route required to reach the lab. |
| 101 | monitor | 10.10.10.20 | Debian 12 | 4GB | Prometheus + Grafana + Alertmanager |
| 109 | ingress | 10.10.10.5 | Debian 12 | 512MB | Caddy 공개 진입점 (TLS termination, vhost routing). LXC envelope is Terraform-managed; Caddy vhosts are managed by `ansible/playbooks/ingress.yml` / `ansible/roles/ops-ingress`. |
| 110 | officetel-analyzer | 10.10.10.30 | Debian 12 | — | Docker 워크로드 (외부 운영). **건드리지 말 것** — W1 에서 충돌로 cleanup 한 적 있음. |
| 111 | ladder | 10.10.10.34 | Alpine | 128MB | Legacy static app. LXC envelope is Terraform-managed; app contents are external until a dedicated role exists. |
| 150 | ops | 10.10.10.50 | Debian 12 | 8GB | **운영 평면**: Postgres 16 (port 5433, DB `app`) + Redis 7 + Caddy + web-app (Bun/Hono, port 3001) + worker. `terraform/modules/ops/` + `ansible/roles/ops/`. 상세: [`09-ops-plane.md`](09-ops-plane.md). |
| 210 | neonnovel-stack | 10.10.10.31 | Debian 12 | 16GB | Legacy Docker/Supabase stack. LXC envelope is Terraform-managed; app deploy remains external. |

## 접근 패턴

### Mac에서 호스트로 (SSH)

```bash
# Tailnet 경유 (권장, 방화벽 tighten 후 유일한 path)
ssh -i ~/.ssh/hetzner_pve root@10.10.10.1

# 비상 경로 (public IP, fail2ban + UFW Tailnet-only이지만 Tailnet에 있으면 통과)
ssh -i ~/.ssh/hetzner_pve root@195.201.80.242
```

### Mac에서 LXC로 (SSH)

```bash
# Tailscale 라우트 승인된 후
ssh -i ~/.ssh/hetzner_pve root@10.10.10.20

# Tailscale 안 되면 ProxyJump
ssh -i ~/.ssh/hetzner_pve -o ProxyJump=root@195.201.80.242 root@10.10.10.20
```

### 브라우저 UI

- Proxmox: `https://10.10.10.1:8006` (또는 `just ui`)
- Grafana: `http://10.10.10.20:3000` (또는 `just grafana`) — admin/admin 초기, 첫 로그인 시 변경

## IaC 레이어 매핑

| 레이어 | 디렉토리 | 책임 |
|--------|---------|------|
| Phase 0: Rescue → Debian | `bootstrap/01-install-debian.sh` | installimage + sshd |
| Phase 1: Debian → Proxmox | `bootstrap/02-install-proxmox.sh` | apt repo + 커널 |
| Phase 2: 데이터 풀 | `bootstrap/03-zfs-data-pool.sh` | ZFS mirror, datasets |
| Phase 3: 네트워크 | `bootstrap/04-network-config.sh` | vmbr0/vmbr1, NAT |
| Phase 4: 호스트 보안 | `bootstrap/05-host-hardening.sh` | UFW, fail2ban, sshd, sysctl |
| Phase 5: Tailscale | `bootstrap/06-tailscale-router-lxc.sh` | CT 100 |
| Phase 6: 방화벽 잠금 | `bootstrap/07-tighten-firewall.sh` | Tailnet-only ingress |
| 컨테이너 정의 | `terraform/environments/prod/main.tf` | LXC 모듈 인스턴스 |
| 컨테이너 모듈 | `terraform/modules/{lxc-base,monitoring,workload}/` | bpg/proxmox 리소스 |
| OS 설정 | `ansible/roles/{common,prometheus,grafana,alertmanager,proxmox-host}/` | post-provisioning |
| 검증 | `tests/smoke/0{1,2,3}-*.bats` | host/tailscale/monitoring 테스트 |

## 외부 의존성

- **Hetzner Robot** (서버 reset, rescue mode 진입) — Mac 브라우저에서만
- **Hetzner DNS** — 사용 안 함 (도메인 미등록)
- **Tailscale 컨트롤 플레인** (login.tailscale.com) — auth + 라우트 승인
- **Debian / Proxmox apt repos** — 정기 업그레이드
- **GitHub raw / releases** — node_exporter, prometheus, grafana, alertmanager 바이너리

## 알아둘 것

- **백업 = 없음 (v1)**. 명시적으로 postpone. 추가는 `RUNBOOK.md`에 vzdump+Hetzner Storage Box 템플릿 있음.
- **HA = 없음**. 단일 노드. 박스 다운 = 전체 다운.
- **시계열 데이터 보존** = Prometheus 기본 15일 (변경하려면 `prometheus_retention` defaults 수정).
- **로그 중앙화 = 없음**. 각 컨테이너 journald 로컬. Loki 추가 가능하지만 v1 범위 외.

## 다음

- 워크로드 추가 → `02-deploy-workload.md`
- 모니터링 통합 → `03-monitoring.md`
- 노출 결정 → `04-firewall-and-access.md`

# 08 — Ops Plane (CT 150)

"운영 평면" = 우리 사업의 모든 stateful·중앙 서비스가 모여 사는 단일 LXC. 이 reference 는 *CT 150 ops 가 뭔지, 어떻게 작동하는지, 어디를 만질 때 무엇을 깨뜨릴 위험이 있는지* 를 진입자(사람 또는 AI) 가 5분 안에 이해할 수 있도록 정리한다.

상세 W1 결정 사항·gotcha 는 `docs/ops-w1-bootstrap.md` 에 있음. 이 문서는 **현재 상태 사실 매핑** + **변경 시 진입점**.

## 한 줄 정의

> CT 150 ops 는 *사업 전체의 control plane* — 사용자 DB, 세션·매직링크, 큐(Redis), API 서버, 백그라운드 워커, 그리고 그 앞단의 reverse proxy 를 한 LXC 안에 모았다. 사이트 LXC 들은 W3 부터 별개의 LXC 로 자동 생성되지만, 모든 사용자·결제·구독·잡 데이터는 여기에 있다.

## 토폴로지 한 그림

```
                        Internet
                           │
                  vmbr0  195.201.80.242
                           │
            host iptables PREROUTING :80,:443
                           │
                           ▼
              CT 109 ingress  10.10.10.5
              (Caddy — LE 인증서 발급/갱신, vhost 라우팅)
                  │
                  │ Caddyfile: flow-finders.com → 10.10.10.50:3001
                  ▼
              CT 150 ops  10.10.10.50
              ┌────────────────────────────────────────┐
              │ Caddy            (admin :2019, vhost :80) │  ← local-only
              │ web-app (Bun)    :3001  systemd unit   │
              │ worker  (Bun)    :9091 metrics         │
              │ postgresql-16    :5433  DB=`app`       │
              │ redis-server     :6379  AUTH=vault     │
              └────────────────────────────────────────┘
```

## 서비스 인벤토리 (CT 150)

| 서비스 | 포트 | bind | systemd unit | 비고 |
|---|---|---|---|---|
| `postgresql@16-main` | 5433 | 127.0.0.1 | `postgresql@16-main.service` | DB `app`, user `app`. pgcrypto + citext extension. 5432 가 docker 와 충돌해서 5433 사용. |
| `redis-server` | 6379 | 127.0.0.1 | `redis-server.service` (+ LXC compat override) | password from sops vault. LXC 호환용 `/etc/systemd/system/redis-server.service.d/lxc-compat.conf` 존재. |
| `caddy` | (none) | 127.0.0.1:2019 admin only | `caddy.service` (+ EnvironmentFile drop-in) | 공개 진입은 CT 109 가 담당. CT 150 의 Caddy 는 :80 /healthz + admin API 만. `/etc/systemd/system/caddy.service.d/override.conf` 에 EnvironmentFile. |
| `web-app` | 3001 | 0.0.0.0 | `web-app.service` | Bun + Hono (W2). 현재는 W1 placeholder. EnvironmentFile=/etc/web-app/env (W2 부터). |
| `worker` | 9091 (metrics) | 127.0.0.1 | `worker.service` | BullMQ consumer (W3+). 현재는 placeholder. |

전부 5 개 systemd 유닛 모두 `enabled` + `active`. `just test` 의 W1 7-assertion 이 이를 검증.

## 데이터 경로

- **DB**: `/var/lib/postgresql/16/main/` — Proxmox subvol-150-disk-0 위 ext4 (32GB). ZFS dataset 직접 매핑 아님 (W3 에서 사이트 LXC 가 ZFS dataset mount 패턴 적용 예정).
- **Redis AOF/RDB**: `/var/lib/redis/`
- **Caddy 상태**: CT 150 의 Caddy 는 인증서 발급 안 함 (CT 109 가 담당). config/data 디렉토리는 비어 있음.
- **web-app 코드**: `/opt/web-app/` — W2 부터 `ansible/roles/ops/tasks/web-app-deploy.yml` 가 `apps/web/` 을 rsync.
- **시크릿**: `/etc/web-app/env` (mode 0640, owner root, group app) — `ansible/group_vars/ops.yml` 의 sops vault 를 ansible 가 풀어서 작성.

## 시크릿 (sops + age vault)

`ansible/group_vars/ops.yml` 가 sops 로 암호화. age private key 는 `~/.config/sops/age/keys.txt` (Mac/dev 호스트). **반드시 2곳 백업 — 분실 시 모든 vault 복호화 영구 불가**.

W1 시점 키 인벤토리:

| vault key | 용도 |
|---|---|
| `vault_pg_app_password` | DB `app` 계정 |
| `vault_pg_super_password` | postgres superuser |
| `vault_redis_password` | Redis AUTH |
| `vault_ops_domain` | `flow-finders.com` (LE 발급 도메인) |

W2 부터 추가 예정 (현재 plan: `docs/superpowers/plans/2026-05-18-w2-auth-payment.md`):
- `vault_toss_client_key` / `vault_toss_secret_key` — Toss Payments
- `vault_resend_api_key` — 트랜잭션 메일
- `vault_session_secret` — 쿠키 서명

## CT 150 의 진입 경로

| 무엇 | 명령 |
|---|---|
| SSH (root, key) | `ssh -i ~/.ssh/hetzner_pve root@10.10.10.50` |
| Postgres psql | `ssh root@10.10.10.50 'sudo -u postgres psql -p 5433 -d app'` |
| Redis CLI | `ssh root@10.10.10.50 'redis-cli -a $(sops --decrypt ... | grep redis_password) PING'` |
| web-app 로그 | `ssh root@10.10.10.50 'journalctl -u web-app -f'` 또는 `just web-logs` (W2) |
| systemd 상태 (전체) | `ssh root@10.10.10.50 'systemctl --no-pager status caddy postgresql redis-server web-app worker'` |
| 내부 healthz | `ssh root@10.10.10.50 'curl -fsS http://127.0.0.1:3001/healthz'` |
| 공개 healthz | `curl -fsS https://flow-finders.com/healthz` |

## CT 150 변경 = 어디를 만지는가

| 변경 의도 | 진입점 |
|---|---|
| 컨테이너 자체 (CTID/IP/리소스) | `terraform/modules/ops/` + `terraform/environments/prod/ops.tf` |
| 패키지·설정·서비스 | `ansible/roles/ops/` + `ansible/playbooks/ops.yml` |
| `just ansible-ops` 가 한 번에 적용. `--tags=web-app` 으로 부분 적용 가능 (W2). |
| 공개 ingress (vhost / 도메인 추가) | `ansible/roles/ops-ingress/` + `ansible/playbooks/ingress.yml` (대상 호스트 = CT 109) |
| 시크릿 | `sops ansible/group_vars/ops.yml` 편집 → `just ansible-ops` 재실행 |
| 마이그레이션 | W2 부터 `apps/web/drizzle/*.sql` 추가 + `just ansible-ops --tags=web-app` (web-app-migrate task 가 psql 로 멱등 적용) |
| 새 LXC 추가 (워크로드 / 사이트) | CT 150 건드리지 말고 별도 `terraform/modules/<name>/` 만들 것 — ops 평면은 단일성 유지 |

## 알려진 위험 / 안전 가드

- **CTID 150 + IP 10.10.10.50 은 고정**. W1 에서 CT 200/10.10.10.30 으로 시도했다가 CT 110 officetel-analyzer 와 IP 충돌, ghost LXC 사장. `docs/ops-w1-bootstrap.md` 의 W1.5 섹션 참조.
- **CT 110 (officetel-analyzer) 은 외부 운영 — 절대 만지지 말 것**. `playbooks/cleanup-ct110.yml` 가 W1.5 에서 우리 잘못 설치한 흔적 제거함. 추가 작업 시 그 playbook의 inventory 가 우리 footprint 만 건드리도록 보장.
- **5433 포트**: docker 의 5432 와 충돌해서 5433 로 정착. 클라이언트 코드는 절대 5432 사용 금지 — `DATABASE_URL` 에서 명시.
- **Redis on LXC**: 표준 systemd hardening (`PrivateUsers`, `ProtectProc=invisible`, `ProtectSystem=strict`) 가 Proxmox LXC 에서 fail. ops role 의 `lxc-compat.conf` drop-in 으로 비활성화. 이거 지우면 부팅 안 됨.
- **Caddy LE 발급은 CT 150 책임 아님**: CT 109 가 발급. CT 150 의 Caddy 가 admin :2019 외 다른 포트 열려고 하면 `:80 /healthz` 와 충돌 없게 주의.
- **Bun 바이너리**: `/usr/local/bin/bun` 은 *심볼릭 링크 아닌 복사본*. `app` user 가 `/root/.bun/` 통해 접근하면 mode 700 으로 막힘. ansible 가 이미 복사 처리.
- **로케일**: `en_US.UTF-8` 가 LXC 베이스 이미지에 미생성. ops role 이 `locale-gen` 후 `/etc/default/locale` 설정. PG `initdb` 가 이 로케일 사용.

## 백업 (현재 = 없음)

ZFS subvol-150-disk-0 의 snapshot 은 W3 이후 검토. v1 백업 전략은 `RUNBOOK.md` 의 vzdump + Hetzner Storage Box 템플릿.

W2 후 첫 사용자 결제 발생 전 반드시 백업 자동화 활성화 — 그전엔 데이터 손실 = 작업 1-2 주 손실.

## W1 / W1.5 / W2 진행 상태

| 단계 | 결과 |
|---|---|
| W1 — Ops CT 부트스트랩 | 완료 (5 systemd 유닛 GREEN, public `flow-finders.com/healthz` 200) |
| W1.5 — CT 200 → CT 150 이전 + CT 109 vhost 모델 | 완료 (PR #1, 7/7 bats GREEN) |
| W2 — 인증/결제 백본 (Lucia + Toss + magic link) | 진행 중 (`docs/superpowers/plans/2026-05-18-w2-auth-payment.md`) |

## 관련 reference

- 03-monitoring.md — CT 150 prometheus 타깃 추가는 자동 (node_exporter)
- 04-firewall-and-access.md — public ingress 모델, CT 109 의 :80/:443 owner 역할
- 06-troubleshooting.md — psql/redis/systemd 함정
- 07-operations.md — 백업/업그레이드/키 회전 (현재 미정)

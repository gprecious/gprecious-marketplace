# 08 — PostgreSQL Managed Appliance

이 문서는 `hetzner-master` 랩에서 PostgreSQL DB를 새로 만들 때 따르는 **Postgres Managed Appliance Template** 기준이다. 목표는 AWS RDS의 운영 편의성, 복구성, 관측성을 최대한 가져오되, 단일 Hetzner Proxmox 노드의 한계를 숨기지 않는 것이다.

## Agent routing

사용자가 "Postgres DB 생성", "RDS 같은 DB", "managed Postgres", "Postgres appliance"를 요청하면 이 reference를 먼저 읽는다.

그 다음 필요한 파일만 추가로 읽는다:

| 필요 | 읽을 문서 |
|---|---|
| 네트워크/IP/CTID 규약 | `references/01-architecture.md` |
| LXC router/backup-relay 생성 | `references/02-deploy-workload.md` |
| Prometheus/Grafana/Alertmanager | `references/03-monitoring.md` |
| copy-paste Terraform/Ansible skeleton | `references/05-templates.md` |
| 장애 진단 | `references/06-troubleshooting.md` |
| 정기 운영/백업/업그레이드 | `references/07-operations.md` |

## Scope and language

정식 용어는 `CONTEXT.md`의 **Postgres Managed Appliance Template**과 **Postgres Appliance Instance**를 따른다.

금지할 표현:

- "RDS-equivalent HA" — 단일 물리 호스트라 RDS Multi-AZ 가용성을 제공하지 못한다.
- "master/slave" — **Primary** / **Standby**를 쓴다.
- "Postgres image" — raw image 하나가 아니라 Terraform/Ansible/runbook/monitoring/backup을 포함한 appliance다.

## Instance factory model

이 appliance는 one-off DB 서버가 아니라 **Instance Factory**로 설계한다. DB appliance set을 만들 때마다 아래 입력값으로 하나의 complete instance set을 생성해야 한다.

v1의 factory surface는 **Terraform module 호출을 직접 추가하는 방식**이다. 별도 `instances/*.yml` manifest나 code generator는 만들지 않는다. 이 repo의 기존 운영 모델처럼 `terraform/environments/prod/main.tf`에 명시적인 module block을 추가하고, Ansible inventory는 Terraform output에서 동기화한다.

기본 운영 모델은 **shared-first**다. 하나의 Postgres Appliance Instance 안에 여러 **Logical Database**를 만든다. 용량, 복구, 보안, 업그레이드 경계가 독립적으로 필요할 때만 **Dedicated Postgres Appliance Instance**를 새로 만든다.

필수 입력:

| 입력 | 예 |
|---|---|
| `instance_name` | `qplace-prod` |
| `postgres_version` | `17` |
| `primary_vmid` / `standby_vmid` | `300` / `301` |
| `router_ctid` | `302` |
| `primary_ip` / `standby_ip` | `10.10.10.100` / `10.10.10.101` |
| `router_ip` | `10.10.10.102` |
| `shared_backup_relay` | `postgres-backup-relay` |
| `pooled_database_endpoint` | `10.10.10.102:6432` |
| `raw_database_endpoint` | `10.10.10.102:5432` |
| `backup_repository` | `home:/mnt/das/<instance_name>` |
| `retention_days` | `14` |
| `monthly_retention_months` | `6` |
| `parameter_profile` | `small-shared` |

logical database 입력:

| 입력 | 예 |
|---|---|
| `database_name` | `qplace_prod` |
| `owner_role` | `qplace_owner` |
| `app_role` | `qplace_app` |
| `migration_role` | `qplace_migrator` |
| `extensions` | `["pgcrypto", "uuid-ossp"]` |

기본 topology:

| 구성요소 | 실행 단위 | 역할 |
|---|---|---|
| Primary | VM | write를 받는 PostgreSQL |
| Recovery Standby | VM | streaming replication, restore validation, manual failover |
| Postgres Router | LXC | stable database endpoint, pgBouncer connection pooling, 현재 primary로 TCP routing |
| Backup Relay | shared LXC | Tailscale `home:/mnt/das` mount, backup repository 접근 격리 |

## Design baseline

1. PostgreSQL 노드는 **VM**으로 만든다. DB는 filesystem, WAL flush, kernel/sysctl, reboot, disk resize, recovery 경계를 명확히 가져야 한다.
2. Router와 Backup Relay는 **LXC**로 만든다. 둘 다 stateless 또는 재생성 가능한 operational component다.
3. 초기 topology는 **Primary 1대 + Recovery Standby 1대 + Manual Failover**다.
4. 앱은 DB 노드 IP가 아니라 **Database Endpoint**만 본다.
5. standby는 v1에서 application read endpoint로 노출하지 않는다. read scale-out은 후속 기능이다.
6. PITR은 v1 범위다. base backup + WAL archive로 특정 시점 복구가 가능해야 한다.
7. 기본 backup repository는 Tailscale `home:/mnt/das`이며, DB VM은 직접 mount하지 않고 shared Backup Relay를 통해 접근한다.
8. S3-compatible object storage는 규모와 내구성 요구가 커질 때 후속 승격 대상으로 둔다.
9. 기본 PostgreSQL major version은 **17**이다. 구현 직전에 PostgreSQL community와 RDS 지원 현황을 다시 확인하고, 해당 major의 최신 안정 minor를 사용한다.
10. PostgreSQL은 golden image에 bake하지 않는다. VM은 OS template로 만들고, PostgreSQL 17 설치와 설정은 PGDG apt repository + Ansible role로 관리한다.
11. 기본은 shared appliance다. 여러 logical database가 하나의 primary/standby pair, backup policy, failover boundary, upgrade window를 공유한다.
12. 각 logical database는 3-role 권한 모델을 사용한다: owner, app, migrator.
13. PostgreSQL engine settings는 hand edit하지 않고 **Postgres Parameter Profile**로 관리한다.
14. v1부터 connection pooling을 제공한다. 앱은 기본적으로 pgBouncer를 통과하는 **Pooled Database Endpoint**에 연결한다.
15. Primary와 Recovery Standby에는 `postgres_exporter`를 기본 설치하고 Prometheus scrape target으로 등록한다.
16. PITR/base backup/WAL archive 도구는 `pgBackRest`를 기본으로 사용한다.

## Capacity profile

단일 Hetzner 서버의 ZFS data pool은 작다. 기본 profile은 작게 시작하고 필요할 때 늘린다.

기본 `small` profile:

| 항목 | 기본값 |
|---|---|
| VM OS disk | 12GB |
| PGDATA disk | 32GB |
| WAL disk | 별도 분리 없음 |
| Router LXC disk | 2-4GB |
| Backup Relay LXC disk | 4-8GB |
| PGDATA warning | 70% |
| PGDATA critical | 85% |

Dedicated appliance를 새로 만들기 전에 먼저 shared appliance 안의 logical database로 충분한지 확인한다. Dedicated appliance는 아래 중 하나가 참일 때만 선택한다:

- 해당 workload가 독립 PITR/restore window를 요구한다.
- 해당 workload가 독립 maintenance/major upgrade window를 요구한다.
- 해당 workload의 데이터 크기나 I/O가 shared appliance의 다른 logical database에 영향을 준다.
- 해당 workload가 별도 보안 경계나 access policy를 요구한다.
- 해당 workload가 장기적으로 다른 host나 managed service로 분리될 가능성이 높다.

## Default shared appliance reservation

새 logical database 요청의 기본 대상은 `shared-postgres-prod`다.

| 항목 | 값 |
|---|---|
| `instance_name` | `shared-postgres-prod` |
| primary VMID / IP | `160` / `10.10.10.110` |
| standby VMID / IP | `161` / `10.10.10.111` |
| router CTID / IP | `173` / `10.10.10.112` |
| pooled endpoint | `10.10.10.112:6432` |
| raw endpoint | `10.10.10.112:5432` |

agent는 새 DB 요청을 받으면 먼저 이 shared appliance에 logical database를 추가할 수 있는지 판단한다. dedicated appliance는 capacity, recovery, security, upgrade 경계가 맞지 않을 때만 제안한다.

## Logical database permissions

Shared appliance에서는 database별 권한 경계를 반드시 만든다. 새 logical database는 아래 3개 role을 기본으로 생성한다.

| Role | 용도 | 앱 런타임 사용 |
|---|---|---|
| `<db>_owner` | database/schema 소유자 | 금지 |
| `<db>_app` | 애플리케이션 runtime 연결 | 허용 |
| `<db>_migrator` | migration/DDL 실행 | 배포 시에만 허용 |

기본 원칙:

1. 앱은 `<db>_app`으로만 연결한다.
2. migration 도구는 `<db>_migrator`로만 연결한다.
3. owner role password는 일반 앱 환경변수에 넣지 않는다.
4. 다른 logical database의 schema/table 권한은 부여하지 않는다.
5. superuser는 appliance 운영자 전용이며 앱/마이그레이션에는 주지 않는다.

## Extensions

Shared appliance에서는 PostgreSQL extension을 allowlist로 관리한다. logical database 요청에 extension이 포함되면 아래 기준을 먼저 적용한다.

기본 allowlist:

- `pgcrypto`
- `uuid-ossp`
- `citext`
- `pg_trgm`
- `btree_gin`
- `btree_gist`

appliance-level 기본 활성화 후보:

- `pg_stat_statements` — 기본 활성화

별도 검토:

- `postgis` — dependency와 resource footprint가 커서 dedicated appliance 검토 대상
- `timescaledb` — 운영 특성이 달라 dedicated appliance 또는 별도 profile 검토 대상

규칙:

1. allowlist 밖 extension은 즉시 설치하지 않고 운영 영향도를 검토한다.
2. extension 요구가 shared appliance의 upgrade/recovery 경계를 복잡하게 만들면 dedicated appliance를 제안한다.
3. extension 설치 여부는 logical database 입력값에 명시한다.

## Secrets

Secret 값은 git에 넣지 않는다. instance/database별 secret은 repo의 gitignored `secrets/` 아래에 둔다.

권장 파일:

```text
secrets/postgres-appliance/<instance_name>.env
secrets/postgres-appliance/<instance_name>.<database_name>.env
```

원칙:

1. 문서와 role defaults에는 secret key 이름만 둔다.
2. 실제 password, replication credential, backup repository credential은 `secrets/`에서 runtime에 주입한다.
3. `owner` password는 앱 환경변수에 배포하지 않는다.
4. `app` password와 `migrator` password는 분리한다.
5. 필요해지면 `sops` 또는 `ansible-vault`로 승격한다.

## Parameter profiles

RDS parameter group에 해당하는 개념은 **Postgres Parameter Profile**이다. 운영자는 DB VM에 들어가 `postgresql.conf`를 직접 수정하지 않는다. Ansible role이 profile 값을 렌더링하고, reload/restart 필요 여부를 드러내야 한다.

v1 기본 profile:

```yaml
postgres_parameter_profile: small-shared
```

`small-shared`의 의도:

- 378GB ZFS data pool에서 여러 logical database를 공유하는 작은 appliance
- conservative memory usage
- PITR/WAL archiving과 streaming replication을 기본 활성화
- connection 수를 무작정 크게 잡지 않고, 필요하면 app-side pooling 또는 pgBouncer를 검토

profile이 관리해야 하는 최소 항목:

| 설정군 | 예 |
|---|---|
| memory | `shared_buffers`, `effective_cache_size`, `work_mem`, `maintenance_work_mem` |
| connections | `max_connections` |
| WAL/replication | `wal_level`, `archive_mode`, `archive_command`, `max_wal_senders`, `hot_standby` |
| checkpoints | `checkpoint_timeout`, `max_wal_size`, `min_wal_size` |
| autovacuum | `autovacuum`, `autovacuum_max_workers`, threshold/scale factor |
| logging | `log_min_duration_statement`, `log_checkpoints`, `log_lock_waits` |

`small-shared`는 `pg_stat_statements`를 기본 활성화한다. 이 설정은 `shared_preload_libraries`를 사용하므로 restart가 필요하다. query text가 노출될 수 있으므로 조회 권한은 appliance 운영자와 필요한 관측 계정으로 제한한다.

규칙:

1. profile 변경은 Ansible 변수 변경으로만 한다.
2. reload 가능한 설정과 restart 필요한 설정을 role output 또는 runbook에 명확히 표시한다.
3. logical database별 임의 tuning은 기본 금지한다.
4. workload가 shared profile에 맞지 않으면 dedicated appliance 또는 새 profile을 검토한다.

## Connection pooling

v1은 `Postgres Router` 안에 pgBouncer를 포함한다. shared appliance에서 여러 앱이 직접 PostgreSQL backend connection을 늘리면 memory 낭비와 connection storm 위험이 커지기 때문이다.

기본 endpoint:

| Endpoint | 기본 포트 | 용도 |
|---|---:|---|
| Pooled Database Endpoint | `6432` | 앱 runtime 기본 연결 |
| Raw Database Endpoint | `5432` | 운영자, migration, 복구 검증용 제한 경로 |

규칙:

1. 앱 runtime은 기본적으로 Pooled Database Endpoint만 사용한다.
2. migration은 transaction pooling과 충돌할 수 있으므로 Raw Database Endpoint 또는 migration 전용 pgBouncer 설정을 사용한다.
3. Raw Database Endpoint는 Tailnet/internal path에서만 접근 가능해야 하며 public exposure 금지.
4. pgBouncer pool mode는 앱 runtime에 대해 `transaction`을 기본으로 한다.
5. Router reload/failover 절차는 HAProxy backend와 pgBouncer connection drain을 함께 다뤄야 한다.

기본 연결 정책:

```text
app DATABASE_URL       -> <router_ip>:6432  # pgBouncer transaction pooling
migration DATABASE_URL -> <router_ip>:5432  # raw PostgreSQL path
```

## Maintenance window

RDS maintenance window에 해당하는 기본 운영 창은 **일요일 04:00-06:00 KST**다.

적용 대상:

- PostgreSQL minor update
- OS security update 중 reboot 필요한 작업
- PostgreSQL parameter 변경 중 restart 필요한 작업
- standby rebuild/reseed
- restore rehearsal 결과 확인과 후속 조치

원칙:

1. reload 가능한 변경은 평시에 적용할 수 있다.
2. restart/reboot 필요한 변경은 maintenance window 안에서만 적용한다.
3. primary를 먼저 건드리지 않는다. standby에 먼저 적용하고 검증한 뒤 primary 작업을 진행한다.
4. shared appliance에서는 모든 logical database가 같은 maintenance window를 공유한다.

## Failure policy

Manual failover만 지원한다. 자동 failover는 split-brain 방지 quorum이 준비될 때까지 넣지 않는다.

failover 절차의 최소 조건:

1. 기존 Primary가 write를 계속 받을 수 없는 상태임을 확인한다.
2. Recovery Standby의 replication lag와 마지막 replay 위치를 확인한다.
3. 기존 Primary가 나중에 살아나도 write를 받지 못하도록 fencing한다.
4. Standby를 promote한다.
5. Postgres Router의 backend를 새 Primary로 바꾸고 reload한다.
6. 앱이 동일 Database Endpoint로 write 가능한지 확인한다.
7. 이전 Primary는 폐기하거나 새 Standby로 재동기화한다.

Backup Relay 또는 `/mnt/das` 장애는 DB write를 막지 않는다. 대신 **Archive Backlog**를 alert로 올리고, local WAL storage가 위험해지기 전에 operator가 복구해야 한다.

## Backup and retention

기본 정책:

- PITR window: 14일
- base backup: 매일 1회
- WAL archive: 연속 보관
- monthly long-term backup: 6개월 보관
- restore rehearsal: 월 1회

백업 도구:

- 기본: `pgBackRest`
- v1 repository: shared Backup Relay를 통한 `home:/mnt/das/postgres-appliance/<instance_name>/`
- 후속 repository: S3-compatible object storage
- DB VM은 `/mnt/das`를 직접 mount하지 않는다. pgBackRest는 DB VM에서 Backup Relay로 SSH push/remote execution 방식으로 repository에 접근한다.

`pg_basebackup` 단독 스크립트는 v1 기본 도구로 쓰지 않는다. retention, WAL archive, restore target time, 검증 로직을 직접 많이 만들어야 하기 때문이다.

초기 backup repository:

```text
home:/mnt/das/postgres-appliance/<instance_name>/
```

권장 하위 구조:

```text
base/
wal/
monthly/
restore-rehearsal/
logs/
```

restore rehearsal 규칙:

1. 기본 주기는 월 1회다.
2. shared appliance 전체를 대상으로 한다.
3. 임시 restore VM에 지정 timestamp로 복구한다.
4. PostgreSQL 부팅, smoke query, logical database/schema 존재 여부를 확인한다.
5. 결과는 log artifact 또는 Prometheus metric으로 남긴다.

복구 단위:

1. PITR은 appliance instance 전체 단위로 지원한다.
2. logical database 하나만 특정 시점으로 되돌리는 직접 PITR은 v1에서 지원하지 않는다.
3. logical database 단위 복구가 필요하면 임시 restore VM을 만든 뒤 해당 database를 `pg_dump`/`pg_restore`로 추출/반영한다.
4. workload가 독립 PITR을 요구하면 shared appliance가 아니라 dedicated appliance를 사용한다.

## Shared backup relay

v1은 appliance마다 relay를 만들지 않는다. `postgres-backup-relay` shared LXC 하나가 여러 appliance의 backup repository 접근을 담당한다.

예약:

| 항목 | 값 |
|---|---|
| CTID | `170` |
| hostname | `postgres-backup-relay` |
| IP | `10.10.10.105` |
| pool | `infra` |
| tags | `infra`, `postgres`, `backup-relay`, `prod` |

구조:

```text
postgres-backup-relay
└─ /mnt/das/postgres-appliance/
   ├─ <instance_name_a>/
   └─ <instance_name_b>/
```

원칙:

1. instance별 repository path를 분리한다.
2. instance별 SSH key 또는 forced command로 relay 접근 권한을 분리한다.
3. relay disk는 작게 유지하고, 실제 backup data는 `/mnt/das`에 둔다.
4. relay mount health와 write test를 monitoring한다.
5. relay 장애는 DB write path를 막지 않고 Archive Backlog alert로 드러낸다.

## Monitoring requirements

새 instance는 최소한 아래 항목을 Prometheus/Alertmanager에 노출해야 한다.

기본 구성:

- Primary VM: node_exporter + postgres_exporter
- Recovery Standby VM: node_exporter + postgres_exporter
- Postgres Router LXC: node_exporter + HAProxy/pgBouncer health metric
- Backup Relay LXC: node_exporter + repository mount/write health metric
- Prometheus job: `postgres`
- Grafana dashboard: PostgreSQL overview

| 항목 | 실패 의미 |
|---|---|
| primary PostgreSQL up | DB write path 장애 |
| standby PostgreSQL up | failover 후보 없음 |
| replication lag | standby promote 시 데이터 손실 가능성 증가 |
| last WAL archive success age | PITR window 불신뢰 |
| archive backlog size | primary disk full 위험 |
| last base backup age | restore 불가능 위험 |
| backup relay mount health | repository 접근 장애 |
| router backend health | 앱 endpoint 장애 |
| restore rehearsal result | 백업은 있지만 복구 불능인 상태 |
| pg_stat_statements availability | 쿼리 성능 관측 불가 |

기본 alert severity:

| Severity | 조건 |
|---|---|
| critical | primary down |
| critical | router pooled endpoint down |
| critical | standby down 10분 이상 |
| critical | WAL archive 30분 이상 실패 |
| critical | PGDATA 85% 이상 |
| critical | backup repository write 30분 이상 불가 |
| warning | replication lag 60초 이상 |
| warning | WAL archive 10분 이상 지연 |
| warning | PGDATA 70% 이상 |
| warning | connection usage 80% 이상 |
| warning | last base backup 26시간 초과 |
| warning | restore rehearsal 35일 이상 없음 |

## Implementation note

이 reference는 DB appliance의 결정 기준이다. 실제 Terraform VM module, PostgreSQL Ansible role, pgBackRest/WAL archive role, HAProxy router role, smoke tests가 아직 없으면 먼저 그 구현을 추가한다. 구현할 때도 Proxmox UI 클릭은 금지이며, Terraform/Ansible/bats를 통해 생성하고 검증해야 한다.

새 appliance instance를 만들 때 agent는 generator를 찾거나 만들지 말고, 먼저 `terraform/environments/prod/main.tf`의 명시적 module 패턴을 따른다. DB appliance instance가 충분히 반복되어 중복이 실제 문제가 될 때만 manifest/generator 도입을 다시 논의한다.

새 database 요청을 받으면 먼저 기존 shared appliance에 logical database를 추가할 수 있는지 판단한다. capacity, recovery, security, upgrade 경계가 맞지 않을 때만 dedicated appliance instance를 제안한다.

완료 조건:

```bash
just test
just status
curl -fsS <database-endpoint-health-check>
```

그리고 실제 DB 연결, PITR restore rehearsal, manual failover rehearsal 중 작업 범위에 해당하는 검증을 통과해야 한다.

# 02 — Deploy a Workload Container

신규 LXC 워크로드를 추가하는 end-to-end 절차. **Step 0 (preflight) + 5단계 + 검증**.

## Step 0 — Pre-flight collision check (HARD GATE — 생략 시 IP/CTID 충돌 사고)

> 새 ID 를 **예약 (architecture doc)** 단계에서 추가하는 경우에도 동일 검증이 필요하다 → `references/01-architecture.md` 의 **RESERVATION RULE** 섹션 참조. 예약과 실제 생성 시점이 분리돼 있어 그 사이에 drift 가 끼어들 수 있다 (incident 2026-05-18 CT 150).

새 모듈 코드 한 줄도 쓰기 전에 4가지 충돌을 자동 검출. 한 번이라도 매칭이 나오면 **그 값을 못 쓴다.** (실제로 2026-05-14 today-bible-app vs officetel 가 같은 10.10.10.30 으로 라이브 ARP 경합 사고 있었음 — preflight 누락이 원인.)

```bash
# 변수: 새 컨테이너에 쓸 후보값
NEW_VMID=120
NEW_IP="10.10.10.33"
NEW_HOSTNAME="my-app"

# (1) VMID 충돌 — 라이브 + IaC 양쪽 검사
ssh -i ~/.ssh/hetzner_pve root@10.10.10.1 "pct list | awk -v v=$NEW_VMID '\$1==v {found=1} END{exit !found}'" \
  && { echo "❌ VMID $NEW_VMID 라이브 사용 중"; exit 1; }
grep -E "^\s*vmid\s*=\s*$NEW_VMID\b" terraform/environments/prod/main.tf \
  && { echo "❌ VMID $NEW_VMID IaC 에 이미 정의"; exit 1; }

# (2) IP 충돌 — 라이브 모든 CT eth0 + IaC ipv4 라인 검사
ssh -i ~/.ssh/hetzner_pve root@10.10.10.1 "
  for ct in \$(pct list | awk 'NR>1{print \$1}'); do
    pct exec \$ct -- ip -4 -o addr show eth0 2>/dev/null | awk '{print \$4}' | cut -d/ -f1
  done" | grep -Fxq "$NEW_IP" \
  && { echo "❌ IP $NEW_IP 라이브 사용 중"; exit 1; }
grep -E "ipv4\s*=\s*\"$NEW_IP/" terraform/environments/prod/main.tf \
  && { echo "❌ IP $NEW_IP IaC 에 이미 정의"; exit 1; }

# (3) Hostname 충돌
ssh -i ~/.ssh/hetzner_pve root@10.10.10.1 "pct list | awk '{print \$3}'" | grep -Fxq "$NEW_HOSTNAME" \
  && { echo "❌ hostname $NEW_HOSTNAME 라이브 사용 중"; exit 1; }
grep -E "hostname\s*=\s*\"$NEW_HOSTNAME\"" terraform/environments/prod/main.tf \
  && { echo "❌ hostname $NEW_HOSTNAME IaC 에 이미 정의"; exit 1; }

# (4) Pool/tag governance — 두 결정 미리 하기
echo "→ pool: apps (워크로드) 또는 infra (라우터/모니터링/인그레스) ?"
echo "→ env tag: prod / stg / dev — 반드시 1개"
```

**한 번에 돌리고 싶으면**: `bash tests/smoke/04-pools-and-tags.bats` 가 IP/VMID 유니크 + 모든 모듈 pool_id + env tag 강제 검증한다. 새 모듈 추가 후 `just test` 가 자동으로 이걸 돌린다 — 그래서 git push 전에 `just test` 통과시키는 게 가장 확실한 가드.

| 흔한 실수 | 결과 | 예방 |
|---|---|---|
| 템플릿의 `ipv4 = "10.10.10.30/24"` 를 그대로 두고 commit | 다른 워크로드와 IP 충돌 → 라이브 ARP 경합 | (2) 단계 + bats 04 |
| `pct list` 만 보고 IP 결정 | IaC 에는 있는데 아직 apply 안 한 IP 와 충돌 | (2) 의 grep 단계 같이 돌림 |
| pool_id 미지정 | UI 에 풀 없음, 백업 정책 미적용 | bats 04 + governance 표 |
| env tag 누락 | filter/검색 깨짐 | bats 04 + governance 표 |

## 사전 결정

| 결정 | 기본값 | 언제 바꾸나 |
|------|--------|-----------|
| **OS 템플릿** | `alpine` | Docker/systemd 의존 → `debian` |
| **CTID** | 다음 빈 번호 (110+) | 충돌 회피 위해 `pct list`로 확인 |
| **IP** | 10.10.10.30+ | DB면 100+, 임시면 200+ |
| **memory** | 512MB | 무거우면 늘림. ZFS ARC 8GB는 호스트 캡 |
| **cores** | 1 | CPU bound면 2+ |
| **disk_size** | 8GB | 큰 파일이면 늘림. 추가 마운트는 별도 |
| **features.nesting** | `false` | Docker-in-LXC면 `true` (보안 약해짐) |
| **tags** | `["workload", "<os>", "prod"]` | 분류용. terraform 자동 추가. 환경 태그(`prod`/`stg`/`dev`) 항상 포함 |
| **pool_id** | `apps` | 워크로드면 `apps`, 인프라(라우터/모니터링/인그레스)면 `infra`. 새 서비스 티어가 정당화되면 prod main.tf 에 pool 리소스 추가 |

## Step 1 — Terraform module 호출 추가

`terraform/environments/prod/main.tf` 끝에 추가:

```hcl
module "workload_<name>" {
  source = "../../modules/workload"

  node_name        = var.node_name
  vmid             = 110                          # 다음 빈 번호
  hostname         = "<name>"                     # DNS 친화적
  ipv4             = "10.10.10.30/24"             # 충돌 안 나는 값
  os               = "alpine"                     # alpine | debian
  memory           = 512
  cores            = 1
  disk_size        = 8
  template_debian  = var.templates.debian
  template_alpine  = var.templates.alpine
  ssh_pubkey       = var.ssh_pubkey
  pool_id          = proxmox_virtual_environment_pool.apps.pool_id  # apps | infra
  tags             = ["app", "<name>", "prod"]    # 환경 태그 + 서비스 식별자
}
```

그리고 `output "all_lxc"` 의 map에도 추가 (inventory 자동 생성용):

```hcl
output "all_lxc" {
  value = {
    monitor = { vmid = module.monitoring.vmid, ip = "10.10.10.20", group = "monitoring" }
    "<name>" = { vmid = module.workload_<name>.vmid, ip = "10.10.10.30", group = "workloads" }
  }
}
```

> **CTID/IP 충돌 검증**: Step 0 의 preflight 가 이미 통과했어야 한다. 아니면 `just test` (bats 04) 가 commit 전에 잡는다. 라이브 + IaC 양쪽 모두 검사 — `pct list` 만 보면 IaC 에 있는 미apply 값을 놓침.

> **⚠ pool_id 는 ForceNew**: bpg/proxmox 0.66 기준 `pool_id` 변경은 destroy/recreate 를 유발한다. 새 컨테이너는 정상이지만 **기존 컨테이너의 pool 을 바꾸려면**: lxc-base 모듈은 이미 `lifecycle { ignore_changes = [pool_id] }` 가 걸려있어 terraform 으로 옮길 수 없다. 호스트에서 직접 `pveum pool modify <pool> --vms <ctid> --allow-move 1` 로 옮기고, 이후 `terraform plan` 이 깨끗한지(`No changes.`) 확인. 자세한 사정은 [`docs/wisdom/01-bootstrap-pitfalls.md` #17](../../../docs/wisdom/01-bootstrap-pitfalls.md).

## Step 2 — terraform plan/apply

```bash
test -f secrets/proxmox-api.env
tailscale ping -c 1 10.10.10.1
just tf-plan
# expect: "Plan: 1 to add, 0 to change, 0 to destroy."
just tf-apply
```

CT 130 `agent-host` 에서 실행 중이면 이 preflight 를 생략하지 말 것. `agent-host` 의 checkout 은 Mac 과 gitignored `secrets/` 상태가 다를 수 있다. raw `terraform plan/apply` 대신 `just tf-*` 만 사용해서 `secrets/proxmox-api.env` 가 wrapper 안에서 source 되게 한다. 파일이 없거나 401/permission denied 가 나면 토큰을 추측·재발급하지 말고 사용자에게 provisioning 을 요청한다.

`just tf-plan` 이 `Terraform plan wants to create Proxmox VMID(s) that already exist live` 로 실패하면 새 워크로드 추가를 멈춘다. 이는 config에는 있는데 state에는 없는 live CT/VM이 있다는 뜻이다. state 백업 후 기존 리소스를 import 하거나 stale config를 제거해서 baseline plan을 깨끗하게 만든 뒤 다시 시작한다. 예:

```bash
cd terraform/environments/prod
cp terraform.tfstate "terraform.tfstate.$(date +%Y%m%d-%H%M%S).bak"
. ../../../secrets/proxmox-api.env
terraform import 'module.workload_example.module.lxc.proxmox_virtual_environment_container.this' pve-master/123
cd ../../..
just tf-plan
```

성공하면 컨테이너 생성 + 시작 + SSH 키 주입까지 한 번에.

검증:
```bash
just ssh-host 'pct list | grep <name>'
# expect: <vmid> running <name>

just ssh-host 'pct exec <vmid> -- ip a show eth0'
# expect: inet 10.10.10.30/24
```

## Step 3 — Ansible inventory 동기화

```bash
just inventory-sync
```

이 명령은 `terraform output -json all_lxc`를 읽어서 `ansible/inventory.local.yml`을 생성한다 (gitignored). `inventory.yml` (체크인됨)는 정적 — 새 호스트는 inventory.local.yml에 자동 추가.

수동으로 하려면:

```yaml
# ansible/inventory.yml 의 children.workloads.hosts 에 추가
workloads:
  hosts:
    <name>:
      ansible_host: 10.10.10.30
      ansible_ssh_common_args: "-o StrictHostKeyChecking=accept-new -o ProxyJump=root@195.201.80.242"
```

> Tailscale 라우트 승인 후라면 `ProxyJump` 빼도 됨.

확인:
```bash
cd ansible && ansible -i inventory.local.yml workloads -m ping
# expect: <name> | SUCCESS => { "ping": "pong" }
```

## Step 4 — Ansible role 적용 (common + 앱)

`ansible/playbooks/workload.yml` 가 자동으로 `common` role을 적용. common은 다음을 깔아준다:
- 패키지 (debian: `curl git jq htop` / alpine: `curl git jq htop bash`)
- node_exporter (Prometheus 자동 스크레이프 대상으로 등록됨!)
- sshd 하드닝
- (선택) Tailscale — `tailscale_authkey` env 있으면

```bash
TS_AUTHKEY=tskey-... just ansible-workloads
```

> `TS_AUTHKEY`는 비워둬도 됨 — 그러면 컨테이너에 Tailscale 안 깔림 (vmbr1 only로 충분한 경우 보통 그렇게 함).

### 앱 전용 role 추가하기

`ansible/roles/<app>/tasks/main.yml` 만든 후 `ansible/playbooks/workload.yml` 에 매핑:

```yaml
- hosts: workloads
  gather_facts: true
  roles:
    - role: common
    - role: <app>
      when: inventory_hostname == "<name>"   # 특정 host만
```

또는 별도 playbook (`ansible/playbooks/<app>.yml`) + Justfile target.

role skeleton은 `05-templates.md`.

## Step 5 — 검증 (HARD GATE)

```bash
# 1. Smoke tests 전체
just test
# expect: 21+ tests pass (기존 테스트는 깨지면 안 됨)

# 2. 새 호스트 ping
cd ansible && ansible -i inventory.local.yml <name> -m ping

# 3. node_exporter 작동
ssh -i ~/.ssh/hetzner_pve -o ProxyJump=root@10.10.10.1 root@10.10.10.30 'curl -s localhost:9100/metrics | head -5'

# 4. Prometheus 자동 스크레이프 확인 (1분 정도 기다린 후)
just ssh-host 'pct exec 101 -- curl -s http://localhost:9090/api/v1/targets | jq ".data.activeTargets[] | select(.labels.instance | contains(\"10.10.10.30\")) | .health"'
# expect: "up"

# 5. Grafana 대시보드에 새 호스트 보임
just grafana
# Node Exporter Full → instance 드롭다운에 10.10.10.30 보여야 함
```

전부 통과하면 git commit:

```bash
git add terraform/environments/prod/main.tf ansible/inventory.yml ansible/roles/<app>
git commit -m "feat(workload): add <name> CT <vmid>"
```

## 컨테이너 종류별 추천

### Stateless 웹 앱 (Node/Python)

```hcl
os = "alpine", memory = 512, cores = 1, disk_size = 8
features = { nesting = false }
```

### Docker 호스트 (앱이 docker-compose 위에)

```hcl
os = "debian", memory = 2048, cores = 2, disk_size = 16
features = { nesting = true, keyctl = true }
```

> **주의**: `nesting=true` 는 unprivileged LXC 격리를 약화. host 노출이 신경 쓰이면 풀 VM (terraform/modules/vm-base — 아직 미작성, 필요 시 lxc-base 참고해서 추가) 고려.

### PostgreSQL / Redis (stateful)

```hcl
os = "debian", memory = 4096, cores = 2, disk_size = 32
disk_storage = "data-vm"   # ZFS volume (snapshot 가능)
ipv4 = "10.10.10.100/24"   # DB 대역
```

추가로 ansible role에 `vm.swappiness=10`, ZFS 데이터셋별 `recordsize` 조정 등.

### CI runner / 무거운 빌드

```hcl
os = "debian", memory = 8192, cores = 4, disk_size = 64
features = { nesting = true }
```

> 호스트 RAM 64GB의 절반을 단일 컨테이너가 먹으면 다른 워크로드 압박. ARC 8GB + 모니터 4GB + ts-router 0.25GB 빼고 ~52GB 가용.

## 컨테이너 삭제

```bash
# 1. terraform module 블록 + output 항목 제거
# 2. terraform plan/apply
just tf-plan   # expect: "Plan: 0 to add, 0 to change, 1 to destroy"
just tf-apply  # **사용자에게 확인받은 후만 실행**
# 3. ansible inventory.yml 에서 호스트 제거
# 4. just inventory-sync 재실행
# 5. just test
```

> ZFS 데이터셋이 남아있는 경우 (`subvol-NNN-disk-0`) 수동 정리 필요할 수 있음:
> `just ssh-host 'zfs list | grep subvol-<vmid>' && zfs destroy data/lxc/subvol-<vmid>-disk-0`

## 다음

- 모니터링 더 깊게 → `03-monitoring.md`
- 외부에서 접근 가능하게 만들기 → `04-firewall-and-access.md`
- 코드 템플릿 복붙 → `05-templates.md`
- 막힘 → `06-troubleshooting.md`

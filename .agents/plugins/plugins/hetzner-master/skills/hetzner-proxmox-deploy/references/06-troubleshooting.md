# 06 — Troubleshooting

문제별 진단 명령 + 가장 가능성 높은 원인 + 해결. 함정 16개 전체는 `docs/wisdom/01-bootstrap-pitfalls.md`.

## 빠른 트리아지 (어디서 막혔나)

```
Mac → 외부 인터넷 → Hetzner public IP → 호스트 → vmbr1 → 컨테이너 → 컨테이너 서비스
   1                  2                  3      4       5         6
```

| 신호 | 의심 구간 | 첫 명령 |
|------|----------|--------|
| Mac에서 어디든 안 닿음 | 1 | `ping 8.8.8.8` |
| public IP는 닿는데 SSH 거부 | 2 (fail2ban, UFW) | `nc -zv 195.201.80.242 22` |
| SSH OK, Tailscale 10.10.10.1 안 됨 | Tailscale | `tailscale status` |
| 호스트 OK, 컨테이너 안 보임 | 4 | `just ssh-host 'pct list'` |
| 컨테이너 ping 됨, TCP 안 됨 | 4-5 (UFW FORWARD) | `just ssh-host 'dmesg \| tail -50 \| grep UFW'` |
| 컨테이너 안에서 외부 안 됨 | 4 (NAT) | `pct exec NNN -- curl -fsSI https://google.com` |
| 서비스 포트 안 열림 | 6 | `pct exec NNN -- ss -tlnp` |

## 카테고리별 문제

### Terraform

#### `Error: Provider produced inconsistent final plan`

bpg/proxmox는 가끔 disk 사이즈 비교에서 오작동. 보통 `terraform refresh && terraform apply` 두 번 돌리면 통과. 안 되면 state에서 해당 resource 제거 후 import.

#### `401 Unauthorized` / `Permission denied`

토큰 만료 또는 권한 부족.

```bash
# 토큰 확인
cat secrets/proxmox-api.env
# UI에서 Datacenter → Permissions → API Tokens → terraform 토큰 활성 여부
# 권한: PVEVMAdmin on / (또는 PVE root)
```

토큰 재발급:
```bash
just ssh-host 'pveum user token add terraform@pve main --privsep 0'
# 출력의 secret 을 secrets/proxmox-api.env에 갱신
```

#### `Plan: 0 to add, 0 to change, 0 to destroy` 인데 실제는 다름

state drift. UI에서 누가 손댐. 사용자 확인 후:
```bash
terraform plan -refresh-only
terraform apply -refresh-only
```

#### `Terraform plan wants to create Proxmox VMID(s) that already exist live`

config/state split-brain. Terraform config에는 리소스가 선언돼 있지만 현재 local state에는 없고, Proxmox live host에는 이미 같은 VMID/CTID가 있다. `just tf-plan` / `just tf-apply` wrapper가 의도적으로 막은 상태다.

해결:
```bash
cd terraform/environments/prod
cp terraform.tfstate "terraform.tfstate.$(date +%Y%m%d-%H%M%S).bak"
. ../../../secrets/proxmox-api.env
terraform import '<resource-address>' pve-master/<vmid>
cd ../../..
just tf-plan
```

`just tf-plan` 이 기존 fleet에 대해 clean 해질 때까지 새 workload를 추가하지 않는다. guard를 우회해서 apply 금지.

### Ansible

#### `Could not match supplied host pattern, ignoring: workloads`

inventory에 workloads 그룹이 비어있거나 group이 정의 안 됨. `just inventory-sync` 재실행 + `ansible/inventory.local.yml` 확인.

#### `Failed to connect to the host via ssh` (10.10.10.x)

Tailscale 라우트 미승인. 두 가지 방법:

1. **라우트 승인** (권장): admin console → ts-router → Edit Route Settings → enable 10.10.10.0/24.
2. **ProxyJump 강제**: inventory의 `ansible_ssh_common_args` 에 `-o ProxyJump=root@195.201.80.242`.

확인:
```bash
tailscale status | grep ts-router        # 100.x.x.x 보이면 OK
tailscale ping 10.10.10.1                # 응답하면 라우트 OK
```

#### `community.general.openrc` 누락 / `yaml callback` 누락

ansible-collection `community.general` 12.x 에서 일부 모듈 제거됨. `ansible/requirements.yml` 재설치 + `ansible.builtin.service` 로 fallback. (wisdom #11, #12)

#### node_exporter SHA256 mismatch

체크섬 자체가 잘못 적혔을 가능성. 절대 추측 금지:
```bash
curl -fsS https://github.com/prometheus/node_exporter/releases/download/v1.8.2/sha256sums.txt | grep amd64
# 6809dd0b3ec45fd6e992c19071d6b5253aed3ead7bf0686885a51d85c6643c66  ...
```
`ansible/roles/common/tasks/node_exporter.yml` 의 `checksum:` 갱신.

### LXC / 컨테이너

#### `pct create` 가 "cannot mount 'data/lxc/subvol-XXX-disk-0': no mountpoint set"

ZFS 부모 데이터셋 mountpoint=none 이면 자식 inherit 못 함. wisdom #3.

```bash
just ssh-host 'zfs set mountpoint=/data/lxc data/lxc && zfs set mountpoint=/data/vm data/vm'
```

#### 컨테이너 시작 안 됨, `status: 226/NAMESPACE`

systemd 서비스가 unprivileged LXC에서 금지된 sandboxing knob 사용. `05-templates.md` 의 "unprivileged LXC sandboxing 우회" 적용. (wisdom #10)

진단:
```bash
just ssh-host 'pct exec <CTID> -- journalctl -u <SERVICE> -b --no-pager | tail -30'
# "Failed to set up mount namespacing" 보이면 sandboxing 문제
```

#### `sysctl --system` 으로 컨테이너 안에서 스크립트 중단

unprivileged LXC에서는 kernel.* 일부 쓰기 금지. `set -e` 조합 시 치명적. (wisdom #5)

```bash
# bad
sysctl --system

# good
sysctl --system >/dev/null 2>&1 || true
```

#### Tailscale 컨테이너에서 `tailscale up` 후 인증 URL 안 보임

```bash
just ssh-host 'pct exec 100 -- journalctl -u tailscaled -n 30 --no-pager | grep -i auth'
# 또는
just ts-url
```

너무 빨리 끝나면 다시:
```bash
just ssh-host 'pct exec 100 -- tailscale up --advertise-routes=10.10.10.0/24 --ssh --reset'
```

### 네트워크 / 방화벽

#### LXC끼리 ping은 되는데 TCP는 안 됨

**wisdom #16**: UFW가 bridge-nf-call=1 때문에 intra-bridge TCP를 DROP.

진단:
```bash
just ssh-host 'dmesg | tail -100 | grep "UFW BLOCK.*vmbr1.*vmbr1"'
# [UFW BLOCK] IN=vmbr1 OUT=vmbr1 PHYSIN=veth... PHYSOUT=veth... ... SYN
```

해결 (이미 `bootstrap/05`에 적용됨):
```bash
just ssh-host bash <<'EOF'
sysctl -w net.bridge.bridge-nf-call-iptables=0
sysctl -w net.bridge.bridge-nf-call-ip6tables=0
ufw default allow routed
ufw route allow in on vmbr1 out on vmbr1
ufw route allow in on vmbr1 out on vmbr0
ufw route allow in on vmbr0 out on vmbr1
EOF
```

영구화는 `/etc/sysctl.d/99-pve-bridge.conf` (bootstrap이 작성).

#### 컨테이너에서 외부 인터넷 안 됨

```bash
# 1. 컨테이너 안 라우팅
just ssh-host 'pct exec <CTID> -- ip route'
# default via 10.10.10.1 보여야 함

# 2. 호스트 NAT
just ssh-host 'iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE'
# -o vmbr0 -s 10.10.10.0/24 보여야 함

# 3. 호스트 ip_forward
just ssh-host 'sysctl net.ipv4.ip_forward'
# = 1

# 4. UFW FORWARD
just ssh-host 'ufw status verbose | head -5'
# Default: allow (routed) 보여야 함
```

#### Tailscale 100.x.x.x로 호스트 접근 안 됨 (Tailnet에서)

```bash
# 1. ts-router 가 살아있는지
just ssh-host 'pct exec 100 -- tailscale status'

# 2. subnet route 승인 됐는지
tailscale status | grep "10.10.10.0/24"
# (subnets) 보이면 OK

# 3. Mac에서 ts-router IP로 직접 ping
tailscale ping ts-router

# 4. ts-router 안에서 호스트 ping
just ssh-host 'pct exec 100 -- ping -c 2 10.10.10.1'

# 5. Mac에서 vmbr1로 직접
tailscale ping 10.10.10.1
```

#### Mac에서 `https://10.10.10.1:8006` 시 cert warning

self-signed cert. 정상. 브라우저에서 advanced → proceed.

영구 해결은 ACME (Let's Encrypt) — Tailscale의 [HTTPS for tailnet](https://tailscale.com/kb/1153/enabling-https/) 또는 별도 Caddy ingress.

### 호스트

#### `apt update` 401 on enterprise repo

`bootstrap/05` 가 처리하지만 `apt full-upgrade` 가 부활시킴.

```bash
just ssh-host 'rm -f /etc/apt/sources.list.d/pve-enterprise.list && apt update'
```

영구 차단:
```bash
just ssh-host 'echo "Package: proxmox-ve\nPin: release o=Proxmox Enterprise\nPin-Priority: -1" > /etc/apt/preferences.d/no-enterprise'
```

#### ZFS ARC가 호스트 RAM 다 먹음

기본은 RAM의 50%. bootstrap이 8GB로 cap.

```bash
just ssh-host 'cat /sys/module/zfs/parameters/zfs_arc_max'
# 8589934592 = 8 GiB 이어야 함
```

값이 0이면 (cap 안 됨):
```bash
just ssh-host bash -c '
  echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf &&
  echo 8589934592 > /sys/module/zfs/parameters/zfs_arc_max &&
  update-initramfs -u
'
```

#### `pveproxy` 의 "No valid subscription" 팝업

bootstrap/05가 한 번 패치하지만 `apt upgrade pve-manager`가 부활시킴.

```bash
just ssh-host bash -c '
  sed -i.orig "s/data.status.toLowerCase() !== \\x27active\\x27/false/g" \
    /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js &&
  systemctl restart pveproxy
'
```

### 모니터링

#### Prometheus target DOWN

```bash
just ssh-host 'pct exec 101 -- curl -s http://localhost:9090/api/v1/targets' \
  | jq '.data.activeTargets[] | select(.health != "up") | {instance, lastError}'
```

대부분 원인:
- 타깃 호스트에서 node_exporter 미실행 → `ansible-workloads` 재실행
- Tailnet IP 잘못됨 → inventory 확인
- 방화벽 (위 UFW intra-vmbr1 함정 참조)

#### Grafana 로그인 안 됨

```bash
just ssh-host 'pct exec 101 -- grafana-cli admin reset-admin-password admin'
```

#### Alertmanager 알림 안 옴

```bash
just ssh-host 'pct exec 101 -- curl -s http://localhost:9093/api/v2/alerts | jq'
```

`receivers:` 에 실제 webhook URL이 들어가있는지 확인. 기본 default receiver는 dummy.

## 시스템 전체 진단 (한 줄 헬스 체크)

```bash
just status        # LXC + VM + ZFS + memory dump
just test          # 21+ bats tests
```

`status` 출력 핵심:
```
node: pve-master  proxmox-ve: 8.4.0
load:  0.5 0.3 0.2
mem total/used: 64G / 12G
pct: 100 ts-router running
     101 monitor running
zpool data: ONLINE  378G  2.13G allocated
```

이상 신호:
- mem used가 50G+ → 어떤 컨테이너가 폭주
- zpool degraded → 즉시 SSH 후 `zpool status` 확인
- ts-router stopped → Tailscale 끊김, public IP만 남음

## 로그 위치

| 무엇 | 어디서 |
|------|--------|
| Proxmox host | `/var/log/syslog`, `journalctl -k` |
| UFW drops | `dmesg`, `/var/log/ufw.log` (있으면) |
| fail2ban | `/var/log/fail2ban.log` |
| LXC 시작/중지 | `/var/log/lxc/<CTID>.log` |
| 컨테이너 내부 | `pct exec <CTID> -- journalctl ...` |
| Prometheus | `pct exec 101 -- journalctl -u prometheus -n 50` |
| Grafana | `pct exec 101 -- journalctl -u grafana-server -n 50` |
| Terraform | stdout (`just tf-plan 2>&1 | tee /tmp/tf.log`) |
| Ansible | stdout (`just ansible-... 2>&1 | tee /tmp/ans.log`) |

## 함정 색인 (`docs/wisdom/01-bootstrap-pitfalls.md`)

| # | 함정 |
|---|------|
| 1 | installimage `parted`/`gdisk` 없음 |
| 2 | parted 정렬 에러 (start sector 명시) |
| 3 | ZFS mountpoint=none → 자식 mount 실패 |
| 4 | `ufw allow proto icmpv6` 미지원 |
| 5 | `sysctl --system` unprivileged LXC에서 fail |
| 6 | enterprise repo 부활 |
| 7 | installimage Proxmox preset 없음 |
| 8 | reboot 후 SSH host key 변경 |
| 9 | node_exporter SHA256 절대 추측 금지 |
| 10 | Grafana systemd sandboxing → 226/NAMESPACE |
| 11 | `community.general.openrc` 제거됨 |
| 12 | `community.general.yaml` callback 제거됨 |
| 13 | inventory ProxyJump 필요 (Tailscale 전) |
| 14 | tailscale up before sysctl --system 실패 |
| 15 | public-IP path 으로 bootstrap 가능 |
| 16 | UFW intra-LXC TCP DROP (bridge-nf-call) |

각 항목 전체 내용은 wisdom 파일 직접 참조.

## 막혔을 때 (Last resort)

1. `just ssh-host` 후 직접 진단 — `pct list`, `journalctl -xb -p err`, `dmesg | tail -200`
2. 영향 받는 컨테이너 정지 → 재시도 → 그래도 안 되면 destroy + terraform 으로 재생성
3. ZFS 데이터 살아있는 한 컨테이너 재생성은 안전 (디스크는 보존)
4. 그래도 안 되면 사용자에게 보고 — public IP 노출 변경/주요 인프라 변경은 사용자 결정

## 다음

- 정기 운영 (백업, 키 회전) → `07-operations.md`

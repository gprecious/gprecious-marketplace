# 07 — Operations (Day-2)

정기 운영 작업. 매일/매주/매월/필요시 단위로 분류.

## 매일 (자동)

| 작업 | 어디서 | 검증 |
|------|--------|------|
| unattended-upgrades (보안 패치) | 호스트 cron | `just ssh-host 'tail /var/log/unattended-upgrades/unattended-upgrades.log'` |
| Prometheus 데이터 수집 | CT 101 | `just test` |
| fail2ban 차단 | 호스트 | `just ssh-host 'fail2ban-client status sshd'` |

## 매주 (수동, 5분)

```bash
# 1. 시스템 헬스 체크
just status
just test

# 2. 디스크 사용량
just ssh-host 'zpool list && df -h /'

# 3. 컨테이너별 메모리/CPU
just ssh-host 'for i in $(pct list | tail -n+2 | awk "{print \$1}"); do
  echo "=== CT $i ==="
  pct exec $i -- free -m | head -2
done'

# 4. apt 업그레이드 가능 패키지 확인
just ssh-host 'apt list --upgradable 2>/dev/null | wc -l'

# 5. fail2ban 차단 IP (이상 트래픽 패턴 감지)
just ssh-host 'fail2ban-client status sshd | grep "Banned IP"'
```

## 매월 (15-30분)

### 1. apt 업그레이드 (호스트)

```bash
just ssh-host 'apt update && apt list --upgradable 2>/dev/null | head -20'

# 위험도 낮음: 그냥 진행
just ssh-host 'apt -y full-upgrade'

# 커널 업그레이드 포함 시:
just ssh-host 'apt -y full-upgrade && systemctl reboot'
# reboot 후 5분 대기 → just status 로 정상 부팅 확인

# 부팅 후 확인
just ssh-host 'pveversion --verbose'
just test
```

> **주의**: `pve-manager` 업그레이드는 가끔 `pveproxy` JS 파일을 갱신해서 subscription 팝업 fix가 풀림. 06의 "subscription 팝업" 섹션 참조.

### 2. 컨테이너 OS 업그레이드

```bash
# 모든 컨테이너 한 번에
just ssh-host 'for i in $(pct list | tail -n+2 | awk "{print \$1}"); do
  echo "=== CT $i ==="
  pct exec $i -- bash -c "apt update && apt -y upgrade" 2>/dev/null \
    || pct exec $i -- ash -c "apk update && apk upgrade"  # alpine fallback
done'

# 또는 ansible-site로 일괄 (common role의 패키지 부분이 idempotent)
just ansible-site
```

### 3. Tailscale 업그레이드 (CT 100 + 워크로드 중 Tailscale 사용 시)

```bash
just ssh-host 'pct exec 100 -- bash -c "
  curl -fsSL https://tailscale.com/install.sh | sh &&
  systemctl restart tailscaled
"'

# 검증
just ssh-host 'pct exec 100 -- tailscale version'
```

### 4. Prometheus / Grafana / Alertmanager 버전 업그레이드

`ansible/roles/{prometheus,grafana,alertmanager}/defaults/main.yml` 에서 버전 변수 갱신:

```yaml
prometheus_version: "2.55.0"   # 새 버전
```

```bash
just ansible-monitoring
just test
```

### 5. node_exporter 업그레이드

`ansible/roles/common/defaults/main.yml`:

```yaml
node_exporter_version: "1.9.0"
```

체크섬도 함께 갱신 — wisdom #9, 절대 추측 금지:
```bash
curl -fsS https://github.com/prometheus/node_exporter/releases/download/v1.9.0/sha256sums.txt | grep amd64
```

```bash
just ansible-host && just ansible-workloads && just ansible-monitoring
just test
```

## 분기 (3개월)

### Tailscale auth key 회전

admin console → Settings → Keys → 새 reusable key 생성 → 이전 key revoke. (디바이스는 이미 인증됐으므로 재인증 안 필요)

ts-router 다시 join 필요한 경우 (key revoke된 상태에서 reboot 등):

```bash
just ssh-host 'pct exec 100 -- tailscale up \
  --advertise-routes=10.10.10.0/24 \
  --ssh \
  --auth-key=<new-key>'
```

### Proxmox API 토큰 회전

```bash
# 새 토큰 생성
just ssh-host 'pveum user token add terraform@pve main_v2 --privsep 0'
# 출력의 secret을 secrets/proxmox-api.env 에 갱신

# 잘 되는지 검증
source secrets/proxmox-api.env
just tf-plan

# 이전 토큰 삭제
just ssh-host 'pveum user token remove terraform@pve main'
```

### Grafana admin 비밀번호 회전

```bash
just ssh-host 'pct exec 101 -- grafana-cli admin reset-admin-password <new-pass>'
```

장기적으로 ansible-vault로:

```yaml
# group_vars/all/vault.yml (ansible-vault edit)
vault_grafana_admin_password: "<new-pass>"
```

`grafana_admin_password: "{{ vault_grafana_admin_password }}"` 로 참조하면 `just ansible-monitoring` 으로 회전됨.

### SSH 키 회전 (선택, 더 안전하면)

새 키 생성 + Hetzner Robot 등록 + 호스트 `~/.ssh/authorized_keys` 갱신:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/hetzner_pve_v2 -C "hetzner@$(date +%Y%m)"

# Hetzner Robot 등록
# robot.hetzner.com → Server → SSH keys → Add

# 호스트 + 모든 컨테이너에 새 키 push
just ssh-host 'cat >> ~/.ssh/authorized_keys' < ~/.ssh/hetzner_pve_v2.pub

for ctid in 100 101 110; do  # 실제 CTID들
  just ssh-host "pct push $ctid ~/.ssh/hetzner_pve_v2.pub /tmp/newkey.pub && \
    pct exec $ctid -- bash -c 'cat /tmp/newkey.pub >> /root/.ssh/authorized_keys'"
done

# 새 키로 접속 검증
ssh -i ~/.ssh/hetzner_pve_v2 root@10.10.10.1 'echo OK'

# 이전 키 제거
just ssh-host 'sed -i "/$(cat ~/.ssh/hetzner_pve.pub | awk \"{print \$3}\")/d" ~/.ssh/authorized_keys'
```

> 새 키로 Justfile/스크립트 업데이트 잊지 말 것 (`SSH_KEY` env 또는 default).

## 백업 (현재 = 없음, 추가하기)

v1에서 의도적으로 postpone. 추가는 모듈러:

### 옵션 A: Hetzner Storage Box + vzdump

```bash
# 1. Hetzner에서 Storage Box 발주 (~€3/월, 100GB)

# 2. SSH 마운트 (호스트)
just ssh-host bash <<'EOF'
apt-get install -y cifs-utils
mkdir -p /mnt/backup
cat > /etc/credentials.smb <<CRED
username=<storagebox-user>
password=<storagebox-pass>
CRED
chmod 600 /etc/credentials.smb
echo "//u<NNN>.your-storagebox.de/backup /mnt/backup cifs credentials=/etc/credentials.smb,iocharset=utf8,uid=root,gid=root,vers=3.0 0 0" >> /etc/fstab
mount -a
EOF

# 3. Proxmox storage 등록
just ssh-host 'pvesm add dir backup --path /mnt/backup --content backup'

# 4. 백업 잡 (UI 또는 vzdump.cron)
just ssh-host bash <<'EOF'
cat > /etc/cron.d/vzdump <<CRON
# 매일 03:00 모든 컨테이너 백업, 7일 보존
0 3 * * * root vzdump --all --mode snapshot --compress zstd --storage backup --maxfiles 7 >> /var/log/vzdump.log 2>&1
CRON
EOF
```

### 옵션 B: ZFS 스냅샷 + zfs-auto-snapshot

```bash
just ssh-host 'apt-get install -y zfs-auto-snapshot'

# 기본 스냅샷 정책 (frequent 4 / hourly 24 / daily 7 / weekly 4 / monthly 12)
# /etc/cron.d/zfs-auto-snapshot 자동 설치됨. data/lxc 와 data/vm 자동 적용.

just ssh-host 'zfs list -t snapshot | head'
```

> 스냅샷은 같은 디스크 → 디스크 fail 시 손실. 외부 백업 (옵션 A)와 병행 권장.

### 옵션 C: Restic + 외부 S3-호환 (Hetzner Object Storage)

```bash
just ssh-host bash <<'EOF'
apt-get install -y restic

cat > /etc/restic.env <<ENV
RESTIC_REPOSITORY=s3:hel1.your-objectstorage.com/hetzner-master-backups
RESTIC_PASSWORD=<long-passphrase>
AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>
ENV
chmod 600 /etc/restic.env
source /etc/restic.env
restic init   # 한 번만

# systemd timer로 매일 03:00
cat > /etc/systemd/system/restic-backup.service <<UNIT
[Service]
Type=oneshot
EnvironmentFile=/etc/restic.env
ExecStart=/usr/bin/restic backup /etc /var/lib/vz/dump --tag daily
ExecStartPost=/usr/bin/restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
UNIT

cat > /etc/systemd/system/restic-backup.timer <<TIMER
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
TIMER

systemctl enable --now restic-backup.timer
EOF
```

### 백업 검증 (DR drill, 분기에 1회)

가장 중요함. 백업이 있어도 복구 안 되면 무의미.

```bash
# vzdump 옵션:
just ssh-host 'pct restore 999 /mnt/backup/dump/vzdump-lxc-101-...tar.zst --storage data-lxc'
# CT 999 가 monitor와 동일 상태로 살아있는지 확인 후 destroy

# restic 옵션:
just ssh-host 'source /etc/restic.env && restic snapshots && restic restore latest --target /tmp/restore'
ls /tmp/restore/etc/...
```

## Proxmox 메이저 업그레이드 (PVE 8 → 9 등, 향후 1-2년)

별도 절차 — 공식 [pve8to9](https://pve.proxmox.com/wiki/Upgrade_from_8_to_9) 따름. 핵심:

1. 모든 백업 검증 후 진행
2. `pve8to9` 사전체크 통과
3. apt 소스 변경
4. dist-upgrade
5. reboot

> 단일 노드라서 다운타임 = upgrade 시간 (~30-60분). 워크로드 영향 큰 시간대 피할 것.

## 인시던트 대응 (호스트 다운, 응답 없음)

### 단계 1: Tailscale에서 보임?

```bash
tailscale ping ts-router    # 응답 있으면 ts-router는 살아있음
tailscale ping 10.10.10.1   # 호스트 자체
```

### 단계 2: public IP 응답?

```bash
ping 195.201.80.242
nc -zv 195.201.80.242 22
```

### 단계 3: Hetzner Robot

[robot.hetzner.com](https://robot.hetzner.com) → Server → 195.201.80.242:
- **Reboot** (소프트, 안전 try first)
- **Reset** (하드, soft 안 되면)
- **Rescue Mode + Reset** (Linux 리스큐로 부팅, 디스크 검사 가능)

Rescue mode 진입:
```bash
ssh root@195.201.80.242    # 새 host key, ~/.ssh/known_hosts 정리
mount /dev/md2 /mnt && ls /mnt    # / 마운트
mount /dev/md0 /mnt/boot
chroot /mnt
# 진단/수정
exit
sync && reboot
```

### 단계 4: 디스크 fail

```bash
just ssh-host 'cat /proc/mdstat'      # mdadm
just ssh-host 'zpool status data'      # ZFS
```

mdadm이 degraded면 (sda 또는 sdb fail):
- Hetzner 지원 티켓 → 디스크 교체
- mdadm + ZFS 둘 다 자동 resync (시간 걸림)
- 절차: [Hetzner wiki: Disk replacement](https://docs.hetzner.com/robot/dedicated-server/raid/exchanging-hard-disks-in-a-software-raid)

## 컨테이너 정기 점검

워크로드 LXC 자체 OS 패치는 매월 ansible-site로 충분. 추가로:

```bash
# 디스크 사용량 (각 컨테이너)
just ssh-host 'for i in $(pct list | tail -n+2 | awk "{print \$1}"); do
  echo -n "CT $i: "
  pct exec $i -- df -h / | tail -1
done'

# 메모리 사용량
just ssh-host 'pct list | tail -n+2 | awk "{print \$1}" | xargs -I{} sh -c "echo -n \"CT {} mem: \"; pct exec {} -- free -m | grep Mem | awk \"{print \\\$3 \\\"M / \\\" \\\$2 \\\"M\\\"}\""'
```

너무 차면 terraform module 의 `disk_size` 또는 `memory` 늘리고 `tf-apply`.

> LXC 디스크 확장은 무중단 가능 (online resize). 메모리 변경은 재시작 필요.

## 변경 이력 추적

모든 인프라 변경은 git commit. PR 없는 단독 운영이라도:

```bash
# 변경 후
git status
git diff
git add <files>
git commit -m "ops: <뭐 했나>"
git push
```

`docs/wisdom/` 에도 새로 발견한 함정 추가 → 다음 운영자(자기 자신)가 안 헤맴.

## 끝

- 막힘 → `06-troubleshooting.md`
- 인프라 변경 (새 컨테이너) → `02-deploy-workload.md`
- 모니터링 추가 → `03-monitoring.md`

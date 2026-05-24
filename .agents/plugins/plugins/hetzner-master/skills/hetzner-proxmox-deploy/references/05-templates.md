# 05 — Copy-Paste Templates

흔한 작업의 보일러플레이트. 변수만 바꿔서 사용. 모든 템플릿은 이 lab의 컨벤션 (vmbr1, ZFS data-lxc, common role 등)을 가정.

## 1. Terraform — workload module 호출

`terraform/environments/prod/main.tf` 에 추가:

```hcl
module "workload_<NAME>" {
  source = "../../modules/workload"

  node_name        = var.node_name
  vmid             = <CTID>             # >= 110, pct list로 충돌 확인
  hostname         = "<NAME>"
  ipv4             = "10.10.10.<IP>/24" # 30+ 일반, 100+ DB
  os               = "alpine"            # alpine | debian
  memory           = 512
  cores            = 1
  disk_size        = 8
  template_debian  = var.templates.debian
  template_alpine  = var.templates.alpine
  ssh_pubkey       = var.ssh_pubkey
  pool_id          = proxmox_virtual_environment_pool.apps.pool_id  # apps | infra
  tags             = ["app", "<NAME>", "prod"]    # 환경 태그(prod/stg/dev) 필수
  features         = { nesting = false } # docker면 true + keyctl = true
}
```

`output "all_lxc"` map에도 같이 추가:

```hcl
"<NAME>" = {
  vmid     = module.workload_<NAME>.vmid
  ip       = "10.10.10.<IP>"
  group    = "workloads"
}
```

## 2. Ansible inventory — 정적 엔트리

`ansible/inventory.yml` 의 `workloads.hosts` 에 추가:

```yaml
workloads:
  hosts:
    <NAME>:
      ansible_host: 10.10.10.<IP>
      ansible_ssh_common_args: "-o StrictHostKeyChecking=accept-new -o ProxyJump=root@195.201.80.242"
      # Tailscale 라우트 승인된 후에는 ProxyJump 빼도 됨
      # 추가 host_vars:
      # app_role: postgres        # prometheus.yml.j2 의 조건부 잡에 사용
```

> 또는 `just inventory-sync` 로 terraform output에서 자동 생성.

## 3. Ansible role skeleton

`ansible/roles/<APP>/` 디렉토리:

```
ansible/roles/<APP>/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── tasks/
│   └── main.yml
├── templates/
│   └── (configs)
└── README.md
```

### `defaults/main.yml`

```yaml
---
app_version: "1.2.3"
app_listen: "0.0.0.0:8080"
app_data_dir: "/var/lib/<APP>"
```

### `tasks/main.yml`

```yaml
---
- name: Install dependencies (Debian)
  ansible.builtin.apt:
    name: ["curl", "ca-certificates"]
    state: present
    update_cache: true
  when: ansible_os_family == "Debian"

- name: Install dependencies (Alpine)
  community.general.apk:
    name: ["curl", "ca-certificates"]
    state: present
    update_cache: true
  when: ansible_os_family == "Alpine"

- name: Create app user
  ansible.builtin.user:
    name: <APP>
    system: true
    shell: /sbin/nologin
    create_home: false
    home: "{{ app_data_dir }}"

- name: Create app directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: <APP>
    group: <APP>
    mode: "0755"
  loop:
    - "{{ app_data_dir }}"
    - /etc/<APP>

- name: Download <APP> binary
  ansible.builtin.get_url:
    url: "https://github.com/<org>/<repo>/releases/download/v{{ app_version }}/<APP>-{{ app_version }}-linux-amd64.tar.gz"
    dest: /tmp/<APP>.tar.gz
    checksum: "sha256:<CHECKSUM>"   # 항상 명시 — wisdom #9 참조

- name: Extract
  ansible.builtin.unarchive:
    src: /tmp/<APP>.tar.gz
    dest: /opt/
    remote_src: true
    creates: /opt/<APP>-{{ app_version }}/

- name: Symlink current
  ansible.builtin.file:
    src: "/opt/<APP>-{{ app_version }}"
    dest: "/opt/<APP>"
    state: link

- name: Render config
  ansible.builtin.template:
    src: <APP>.yml.j2
    dest: /etc/<APP>/<APP>.yml
    owner: <APP>
    group: <APP>
    mode: "0644"
  notify: restart <APP>

- name: Install systemd unit
  ansible.builtin.copy:
    dest: /etc/systemd/system/<APP>.service
    mode: "0644"
    content: |
      [Unit]
      Description=<APP>
      After=network.target

      [Service]
      User=<APP>
      Group=<APP>
      ExecStart=/opt/<APP>/<APP> --config /etc/<APP>/<APP>.yml
      Restart=on-failure
      RestartSec=5
      # IMPORTANT: unprivileged LXC에서는 sandboxing knobs를 풀어야 함
      # Grafana role 의 override.conf 참고 (ProtectSystem 등 일체 disable)

      [Install]
      WantedBy=multi-user.target
  notify:
    - daemon reload
    - restart <APP>

- name: Enable + start
  ansible.builtin.systemd:
    name: <APP>
    enabled: true
    state: started
    daemon_reload: true
```

### `handlers/main.yml`

```yaml
---
- name: daemon reload
  ansible.builtin.systemd:
    daemon_reload: true

- name: restart <APP>
  ansible.builtin.systemd:
    name: <APP>
    state: restarted
```

### unprivileged LXC sandboxing 우회

systemd unit이 사이드박싱 (`ProtectSystem`, `PrivateTmp` 등) 쓰면 unprivileged LXC에서 status `226/NAMESPACE` 에러. drop-in으로 다 끄기:

```yaml
- name: Drop sandboxing for LXC
  ansible.builtin.copy:
    dest: /etc/systemd/system/<APP>.service.d/override.conf
    mode: "0644"
    content: |
      [Service]
      ProtectSystem=
      ProtectHome=
      ProtectProc=
      ProcSubset=
      PrivateTmp=
      PrivateDevices=
      PrivateUsers=
      ProtectKernelTunables=
      ProtectKernelModules=
      ProtectKernelLogs=
      ProtectControlGroups=
      RestrictNamespaces=
      LockPersonality=
      MemoryDenyWriteExecute=
      RestrictRealtime=
      RestrictSUIDSGID=
      RemoveIPC=
      CapabilityBoundingSet=
      AmbientCapabilities=
      NoNewPrivileges=
      RestrictAddressFamilies=
      SystemCallFilter=
      SystemCallArchitectures=
      DeviceAllow=
  notify:
    - daemon reload
    - restart <APP>
```

> Grafana role (`ansible/roles/grafana/tasks/main.yml`) 에 실제 적용 사례.

### `playbooks/<APP>.yml`

```yaml
---
- hosts: workloads
  gather_facts: true
  roles:
    - role: common
    - role: <APP>
      when: inventory_hostname == "<NAME>"
```

`Justfile` target도 추가:
```make
ansible-<APP>:
    cd ansible && ansible-playbook -i inventory.local.yml playbooks/<APP>.yml
```

## 4. Bats smoke test

`tests/smoke/0X-<NAME>.bats`:

```bash
#!/usr/bin/env bats
# Smoke tests for <NAME> workload (CT <CTID>, IP 10.10.10.<IP>).

setup() {
  SSH_OPTS=(-i $HOME/.ssh/hetzner_pve -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=4)
  if tailscale ping -c 1 10.10.10.1 >/dev/null 2>&1; then
    PROXY=root@10.10.10.1
  else
    PROXY=root@195.201.80.242
  fi
}

@test "<NAME> container running" {
  run ssh "${SSH_OPTS[@]}" $PROXY 'pct status <CTID>'
  [ "$status" -eq 0 ]
  [[ "$output" == *"running"* ]]
}

@test "<NAME> service active" {
  run ssh "${SSH_OPTS[@]}" $PROXY 'pct exec <CTID> -- systemctl is-active <APP>'
  [ "$status" -eq 0 ]
  [ "$output" = "active" ]
}

@test "<NAME> port responds" {
  run ssh "${SSH_OPTS[@]}" $PROXY 'pct exec <CTID> -- curl -s -o /dev/null -w "%{http_code}" -m 5 http://localhost:8080/health'
  [ "$status" -eq 0 ]
  [[ "$output" == "200" ]]
}

@test "<NAME> in Prometheus" {
  run ssh "${SSH_OPTS[@]}" $PROXY 'pct exec 101 -- curl -s http://localhost:9090/api/v1/targets | jq -r ".data.activeTargets[] | select(.labels.instance | contains(\"10.10.10.<IP>\")) | .health"'
  [ "$status" -eq 0 ]
  [[ "$output" == "up" ]]
}
```

## 5. Custom Prometheus 잡 (조건부)

`ansible/roles/prometheus/templates/prometheus.yml.j2` 끝에:

```yaml
  - job_name: <APP>
    static_configs:
      - targets:
{% for hostname, host_data in hostvars.items() %}
{%   if host_data.app_role is defined and host_data.app_role == '<APP>' %}
          - "{{ host_data.ansible_host }}:{{ <APP>_metrics_port | default(9100) }}"
{%   endif %}
{% endfor %}
```

inventory 호스트에 `app_role: <APP>` 추가하면 자동 포함.

## 6. Alertmanager 룰 group

`ansible/roles/prometheus/templates/alerts.yml.j2`:

```yaml
groups:
  - name: <APP>
    interval: 30s
    rules:
      - alert: <APP>Down
        expr: up{job="<APP>"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "<APP> on {{ $labels.instance }} down"

      - alert: <APP>HighLatency
        expr: histogram_quantile(0.95, rate(<APP>_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "p95 latency >1s on {{ $labels.instance }}"
```

## 7. Justfile target 추가

```make
# === <APP> ===
ansible-<APP>:
    cd ansible && ansible-playbook -i inventory.local.yml playbooks/<APP>.yml

restart-<APP>:
    just ssh-host 'pct exec <CTID> -- systemctl restart <APP>'

logs-<APP>:
    just ssh-host 'pct exec <CTID> -- journalctl -u <APP> -n 50 --no-pager'
```

## 8. Tailscale 컨테이너 (서브넷 라우터, 추가 라우터, 또는 exit node)

`bootstrap/06-tailscale-router-lxc.sh` 패턴. CT 100과 다른 라우트가 필요하거나 redundancy 원하면:

```bash
pct create 102 \
  local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname ts-router-2 \
  --memory 256 --cores 1 \
  --net0 name=eth0,bridge=vmbr1,ip=10.10.10.11/24,gw=10.10.10.1 \
  --features nesting=0,keyctl=1 \
  --unprivileged 1 \
  --onboot 1 \
  --start 1

# Tailscale 필수 디바이스 (TUN)
echo 'lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file' >> /etc/pve/lxc/102.conf

pct restart 102

pct exec 102 -- bash -c '
  curl -fsSL https://tailscale.com/install.sh | sh &&
  systemctl enable --now tailscaled
'

# 별도 auth (tailscale up은 인터랙티브 또는 TS_AUTHKEY)
pct exec 102 -- tailscale up --advertise-routes=10.10.10.0/24 --ssh
```

## 9. cron / systemd timer (정기 작업)

```yaml
- name: Install timer unit
  ansible.builtin.copy:
    dest: /etc/systemd/system/<APP>-cleanup.timer
    content: |
      [Unit]
      Description=<APP> cleanup
      [Timer]
      OnCalendar=daily
      Persistent=true
      [Install]
      WantedBy=timers.target

- name: Install service unit
  ansible.builtin.copy:
    dest: /etc/systemd/system/<APP>-cleanup.service
    content: |
      [Service]
      Type=oneshot
      ExecStart=/opt/<APP>/cleanup.sh

- name: Enable timer
  ansible.builtin.systemd:
    name: <APP>-cleanup.timer
    enabled: true
    state: started
    daemon_reload: true
```

## 10. Secret / vault 패턴

ansible-vault 권장:

```bash
cd ansible
ansible-vault create group_vars/all/vault.yml
# 내용:
# vault_grafana_admin_password: "..."
# vault_slack_webhook: "..."
```

`group_vars/all.yml` 에서 참조:

```yaml
grafana_admin_password: "{{ vault_grafana_admin_password }}"
```

실행 시:
```bash
ansible-playbook ... --ask-vault-pass
# 또는
ansible-playbook ... --vault-password-file=~/.config/ansible-vault-pwd
```

## 다음

- 막혔다 → `06-troubleshooting.md`
- 정기 운영 → `07-operations.md`

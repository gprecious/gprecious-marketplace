# 03 — Monitoring

CT 101 monitor (10.10.10.20)에서 Prometheus + Grafana + Alertmanager + node_exporter (각 호스트)가 작동.

## 자동 통합 (zero config)

`02-deploy-workload.md` 따라 컨테이너를 추가하면:

1. **`common` role**이 컨테이너에 node_exporter (1.8.2) 설치 — `:9100/metrics` 노출.
2. **`prometheus.yml.j2` 템플릿**이 ansible inventory의 모든 호스트를 hostvars에서 자동 읽음 — `lxc-node` 잡에 자동 추가.
3. `just ansible-monitoring` 재실행 시 Prometheus config 재로드 → **15초 후 자동 스크레이프 시작**.

확인 (1분 대기 후):

```bash
just ssh-host 'pct exec 101 -- curl -s http://localhost:9090/api/v1/targets' \
  | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health}'
```

## 스택 구성

| 컴포넌트 | 포트 | 위치 (CT 101) | 설치 root |
|---------|------|---------------|----------|
| Prometheus | 9090 | `/opt/prometheus/` | `ansible/roles/prometheus/` |
| Alertmanager | 9093 | `/opt/alertmanager/` | `ansible/roles/alertmanager/` |
| Grafana | 3000 | apt `grafana` | `ansible/roles/grafana/` |
| node_exporter | 9100 | `/opt/node_exporter/` | `ansible/roles/common/tasks/node_exporter.yml` |
| pve_exporter | 9221 | 호스트 venv | `ansible/roles/proxmox-host/` |

## 기본 스크레이프 잡

`ansible/roles/prometheus/templates/prometheus.yml.j2` 가 4개 잡을 자동 생성:

| Job | 대상 | 메트릭 |
|-----|------|--------|
| `prometheus` | self (localhost:9090) | Prometheus 내부 |
| `pve-host-node` | 10.10.10.1:9100 | 호스트 node_exporter |
| `pve-host-exporter` | 10.10.10.1:9221 | Proxmox API (pve_exporter) |
| `lxc-node` | 모든 inventory 호스트:9100 | LXC node_exporter |

> **자동 추가 메커니즘**: `prometheus.yml.j2` 마지막 블록이 `hostvars.items()` 를 loop하며 `pve-master`만 빼고 전부 `lxc-node` 타깃으로 등록. inventory에만 추가하면 끝.

## 새 메트릭 추가하기 (사이드카 exporter 패턴)

기존 node_exporter로 부족하면 (예: PostgreSQL → postgres_exporter):

### Step 1 — 워크로드 컨테이너에 exporter 설치

`ansible/roles/<app>/tasks/main.yml` 에 추가:

```yaml
- name: Download postgres_exporter
  ansible.builtin.get_url:
    url: "https://github.com/prometheus-community/postgres_exporter/releases/download/v0.15.0/postgres_exporter-0.15.0.linux-amd64.tar.gz"
    dest: /tmp/postgres_exporter.tar.gz

- name: Extract
  ansible.builtin.unarchive:
    src: /tmp/postgres_exporter.tar.gz
    dest: /opt/
    remote_src: true
    creates: /opt/postgres_exporter-0.15.0.linux-amd64/

- name: systemd unit
  ansible.builtin.copy:
    dest: /etc/systemd/system/postgres_exporter.service
    content: |
      [Unit]
      Description=postgres_exporter
      After=network.target

      [Service]
      User=postgres
      ExecStart=/opt/postgres_exporter-0.15.0.linux-amd64/postgres_exporter
      Environment="DATA_SOURCE_NAME=postgresql://exporter:pass@127.0.0.1:5432/postgres?sslmode=disable"
      Restart=on-failure

      [Install]
      WantedBy=multi-user.target

- name: Enable + start
  ansible.builtin.systemd:
    name: postgres_exporter
    enabled: true
    state: started
    daemon_reload: true
```

### Step 2 — Prometheus 잡 추가

`ansible/roles/prometheus/templates/prometheus.yml.j2` 마지막에:

```yaml
  - job_name: postgres
    static_configs:
      - targets:
{% for hostname, host_data in hostvars.items() %}
{%   if host_data.app_role is defined and host_data.app_role == 'postgres' %}
          - "{{ host_data.ansible_host }}:9187"
{%   endif %}
{% endfor %}
```

inventory에서 해당 호스트에 `app_role: postgres` host_var 추가.

### Step 3 — 재배포

```bash
just ansible-workloads        # exporter 설치
just ansible-monitoring       # prometheus 재로드
```

## Grafana 대시보드 추가

기본 2개 대시보드가 자동 provisioning됨:
- **Node Exporter Full** (1860, rev 37) — 호스트 + 모든 LXC
- **Proxmox VE** (10347, rev 5) — Proxmox 클러스터 view

새 대시보드 추가 — 두 가지 패턴:

### 패턴 A: Grafana.com 공식 대시보드

`ansible/roles/grafana/defaults/main.yml` 에 변수 추가:

```yaml
postgres_dashboard_id: "9628"
postgres_dashboard_revision: "7"
```

`ansible/roles/grafana/tasks/main.yml` 에 task 추가 (기존 `node_exporter_full_revision` 다운로드 task와 동일 패턴):

```yaml
- name: Download postgres dashboard JSON
  ansible.builtin.get_url:
    url: "https://grafana.com/api/dashboards/{{ postgres_dashboard_id }}/revisions/{{ postgres_dashboard_revision }}/download"
    dest: /var/lib/grafana/dashboards/postgres.json
    owner: grafana
    group: grafana
    mode: "0644"
```

### 패턴 B: 커스텀 JSON

직접 만든 대시보드 JSON을 `ansible/roles/grafana/files/dashboards/<name>.json` 에 두고:

```yaml
- name: Copy custom dashboards
  ansible.builtin.copy:
    src: "dashboards/{{ item }}"
    dest: "/var/lib/grafana/dashboards/{{ item }}"
    owner: grafana
    group: grafana
    mode: "0644"
  loop:
    - <name>.json
```

```bash
just ansible-monitoring
# Grafana는 기본 30초 polling으로 신규 대시보드 자동 인식
```

## Alertmanager 룰 추가

`ansible/roles/prometheus/templates/alerts.yml.j2` 편집:

```yaml
groups:
  - name: workload
    interval: 30s
    rules:
      - alert: WorkloadDown
        expr: up{job="lxc-node"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "LXC {{ $labels.instance }} down for 2+ min"
          description: "node_exporter on {{ $labels.instance }} unreachable. Check pct status."

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Memory >90% on {{ $labels.instance }}"
```

```bash
just ansible-monitoring
just ssh-host 'pct exec 101 -- curl -s http://localhost:9090/api/v1/rules' | jq
```

### Alertmanager 통보 채널

기본 receiver는 dummy. 실제 알림 보내려면 `ansible/roles/alertmanager/templates/alertmanager.yml.j2` 에:

```yaml
receivers:
  - name: 'default'
    slack_configs:
      - api_url: '{{ slack_webhook_url }}'   # vault에서 inject
        channel: '#alerts'
```

## Prometheus 데이터 보존 / 디스크 고려

기본 보존: 15일 (Prometheus default). 변경:

```yaml
# ansible/roles/prometheus/defaults/main.yml
prometheus_retention: "30d"
prometheus_retention_size: "5GB"
```

CT 101 disk는 16GB. ~5GB Prometheus + ~3GB Grafana + ~5GB OS = 여유 ~3GB.

## 외부에서 메트릭 보기

```bash
# Tailscale 경로
open http://10.10.10.20:3000   # Grafana
open http://10.10.10.20:9090   # Prometheus
open http://10.10.10.20:9093   # Alertmanager

# Tailscale 안 될 때 SSH tunnel
just grafana-tunnel            # localhost:3000
ssh -L 9090:localhost:9090 -i ~/.ssh/hetzner_pve root@195.201.80.242 \
  -t 'ssh -L 9090:localhost:9090 root@10.10.10.20'
```

## Grafana 비밀번호 관리

초기 admin / admin. 첫 로그인 시 강제 변경. 이후 변경:

```bash
just ssh-host 'pct exec 101 -- grafana-cli admin reset-admin-password <new-pass>'
```

장기적으로는 `ansible/roles/grafana/defaults/main.yml` 에 `grafana_admin_password` 변수 + ansible-vault 권장.

## 모니터링 검증 (smoke tests)

`tests/smoke/03-monitoring.bats` 가 자동으로:
- Grafana / Prometheus / Alertmanager HTTP 200
- 4+ targets UP
- Datasource provisioning
- 대시보드 staged

```bash
just test
```

새 exporter 추가 후에는 03-monitoring.bats 에 테스트 한 줄 추가:

```bash
@test "postgres_exporter scraped" {
  run ssh "${SSH_OPTS[@]}" $PROXY 'pct exec 101 -- curl -s http://localhost:9090/api/v1/targets | jq -r ".data.activeTargets[].labels.job" | sort -u | grep postgres'
  [ "$status" -eq 0 ]
  [[ "$output" == *"postgres"* ]]
}
```

## 다음

- 외부 접근 / 노출 → `04-firewall-and-access.md`
- 템플릿 → `05-templates.md`
- 진단 → `06-troubleshooting.md`

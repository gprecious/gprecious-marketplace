# 04 — Firewall & Access Model

이 lab의 보안 모델은 **"공개 인터넷에서는 거의 안 보이게, Tailnet 안에서만 자유롭게"** 가 기본.

## 보안 경계 한눈에

```
                Public Internet
                       │
                       ▼
      ┌─────────────────────────────────┐
      │ 195.201.80.242 (vmbr0)          │
      │ UFW default deny incoming       │
      │                                 │
      │ 외부에서 허용:                  │
      │   - ICMP (ping)                 │
      │   - UDP 41641 (Tailscale)       │
      │   - TCP 22, 8006 from Tailnet*  │
      │                                 │
      │ * Tailnet = 100.64.0.0/10       │
      │   외부 IP라도 Tailnet 안에 있으면 통과 │
      └────────────┬────────────────────┘
                   │
                   ▼
      ┌─────────────────────────────────┐
      │ vmbr1 (10.10.10.0/24)           │
      │ 호스트가 NAT outbound 제공      │
      │ 컨테이너끼리는 자유 통신        │
      │ (bridge-nf-call=0)              │
      └─────────────────────────────────┘
```

## 3개의 firewall 레이어

| 레이어 | 어디서 | 무엇을 결정 |
|--------|--------|-------------|
| **UFW (호스트)** | `bootstrap/05-host-hardening.sh` + `07-tighten-firewall.sh` | 호스트 진입 + FORWARD (vmbr1 ↔ vmbr0) |
| **Proxmox Firewall** | `/etc/pve/firewall/cluster.fw` | 호스트 + per-VM/CT |
| **컨테이너 내부 iptables/ufw** | 컨테이너 OS | (보통 미사용 — 호스트 레이어로 충분) |

> **현재 활성**: UFW (active). Proxmox firewall은 cluster.fw에 존재하지만 노드/per-VM 활성화 안 됨. 추가 격리가 필요하면 enable.

## UFW 규칙 (현재 적용)

```bash
just ssh-host 'ufw status verbose'
```

핵심 규칙:

```
Default: deny (incoming), allow (outgoing), allow (routed)

# 외부에서 허용 (Tailnet only로 tighten 됨)
22/tcp                ALLOW IN   100.64.0.0/10
8006/tcp              ALLOW IN   100.64.0.0/10
8006/tcp              ALLOW IN   10.10.10.0/24
22/tcp                ALLOW IN   10.10.10.0/24

# Tailscale UDP (handshake)
41641/udp             ALLOW IN   Anywhere

# vmbr1 trust
Anywhere on vmbr1     ALLOW IN

# vmbr1 ↔ vmbr0 forwarding (NAT)
[FORWARD] vmbr1 → vmbr1   (intra-LXC)
[FORWARD] vmbr1 → vmbr0   (NAT outbound)
[FORWARD] vmbr0 → vmbr1   (NAT return)
```

> 중요한 sysctl: `net.bridge.bridge-nf-call-iptables=0`. 이거 안 하면 vmbr1 LXC↔LXC TCP가 UFW FORWARD에 걸려 SYN drop. (`docs/wisdom #16`)

## 흔한 시나리오

### 시나리오 1: Mac → 새 워크로드 (10.10.10.30:8080)

**기본적으로 동작함**. Tailscale 라우트 승인되어 있으면:

```bash
curl http://10.10.10.30:8080/
```

추가 firewall 변경 필요 없음. `vmbr1` 안의 통신은 자유롭고 Tailscale이 Mac을 vmbr1에 합류시킴.

> 만약 안 되면 `06-troubleshooting.md` 의 "Tailscale 경로 안 됨" 섹션.

### 시나리오 2: 컨테이너 → 컨테이너 (10.10.10.30 → 10.10.10.20)

**기본 동작**. bridge-nf-call=0 + UFW route allow 둘 다 적용됨.

확인:
```bash
just ssh-host 'pct exec 110 -- nc -zv 10.10.10.20 9090'
```

### 시나리오 3: 컨테이너 → 외부 인터넷 (apt update 등)

**기본 동작**. 호스트 MASQUERADE가 처리.

확인:
```bash
just ssh-host 'pct exec 110 -- curl -fsSI https://deb.debian.org/'
```

### 시나리오 4: 외부 → 컨테이너 직접 (public 노출, 드물지만 필요할 때)

**금지가 기본**. 정말로 필요하면 명시적 절차:

#### 4a. Caddy/Traefik reverse proxy 컨테이너 패턴 (권장)

새 reverse-proxy LXC 만들고 (CTID 109 권장):

```hcl
module "reverse_proxy" {
  source     = "../../modules/workload"
  vmid       = 109
  hostname   = "ingress"
  ipv4       = "10.10.10.5/24"
  os         = "alpine"
  memory     = 256
  ssh_pubkey = var.ssh_pubkey
  tags       = ["ingress"]
}
```

호스트 UFW + iptables DNAT 으로 80/443을 ingress로 포워드:

```bash
# /root/iptables-ingress.sh — bootstrap에 포함시키거나 ansible role
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 80  -j DNAT --to-destination 10.10.10.5:80
iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to-destination 10.10.10.5:443
iptables -t nat -A POSTROUTING -o vmbr1 -d 10.10.10.5/32 -j MASQUERADE

# UFW
ufw allow 80/tcp
ufw allow 443/tcp
```

iptables 룰 영구화: `iptables-save > /etc/iptables/rules.v4` + `apt install iptables-persistent`.

> Caddy는 `http://app.example.com -> 10.10.10.30:8080` 같은 설정으로 vmbr1 안의 워크로드를 노출. TLS 자동 (Let's Encrypt).

#### 4b. 단일 포트 직접 노출 (PoC, 임시만)

```bash
just ssh-host bash -c '
  iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 8080 -j DNAT --to-destination 10.10.10.30:8080 &&
  ufw allow 8080/tcp comment "temporary <project> public"
'
```

> **반드시 추적**: 어디에 노출했는지 `docs/wisdom/` 또는 RUNBOOK에 기록. 잊으면 영원히 열린 채로 남음.

#### 4c. 절대 안 됨

- 호스트의 8006 (Proxmox UI)을 public open. 누구나 web console 접근. **항상 Tailnet only.**
- SSH 22를 그냥 open. fail2ban 있어도 추가 노출은 0이 베스트.
- 컨테이너에 vmbr0을 직접 attach. 호스트 firewall 우회. 어떤 경우에도 안 함.

## Tailscale 측면

### 현재 활성

- CT 100 ts-router (10.10.10.10) — `--advertise-routes=10.10.10.0/24 --ssh`
- Tailnet name: 사용자 본인 tailnet
- 라우트 승인: admin console에서 enable됨
- Mac 자동으로 100.64.x 받음

### Tailscale ACL (선택)

기본은 `accept everything`. 작업자가 여러 명이면 [Tailscale ACL](https://tailscale.com/kb/1018/acls/) 로 누가 어디 접근하는지 제한:

```jsonc
{
  "tagOwners": {
    "tag:hetzner-prod": ["taejin@..."],
  },
  "acls": [
    { "action": "accept", "src": ["taejin@..."], "dst": ["tag:hetzner-prod:*"] },
    { "action": "accept", "src": ["junior@..."], "dst": ["tag:hetzner-prod:3000,9090"] }
  ]
}
```

ts-router에 태그 부여:
```bash
just ssh-host 'pct exec 100 -- tailscale up --advertise-tags=tag:hetzner-prod --advertise-routes=10.10.10.0/24 --ssh'
```

### Tailnet 키 (auth key) 관리

- **auth key 회전 권장**: 90일. admin console → Settings → Keys.
- **재인증 필요 없음** (디바이스 한 번 등록되면 keepalive로 유지).
- ephemeral key 사용 = 컨테이너 destroy 시 자동 정리.

## Proxmox UI 노출 정책

- 경로: `https://10.10.10.1:8006` (Tailnet only)
- public IP `https://195.201.80.242:8006` 도 listen 중이지만 UFW가 deny.
- Tailnet에 있어도 자체 인증 필요 (root + Linux PAM).
- API 토큰 (`secrets/proxmox-api.env`) 은 terraform 전용 — 별도 user `terraform@pve` + 토큰. UI 로그인 안 됨.

## 변경 검증

방화벽 변경 후:

```bash
# 1. UFW 적용 확인
just ssh-host 'ufw status numbered'

# 2. 외부에서 닫힌 게 닫힌지 (Tailscale 끄고)
nc -zv 195.201.80.242 22       # Tailscale on: SUCCESS, off: connection refused

# 3. Tailnet 안에서 열린 게 열린지
ssh -i ~/.ssh/hetzner_pve root@10.10.10.1 'echo OK'

# 4. 컨테이너 outbound 살아있는지
just ssh-host 'pct exec 101 -- curl -fsSI https://google.com' | head -1

# 5. Smoke tests
just test
```

## Red flags

- "잠깐 풀어두자" — 절대 안 됨. 사용한 즉시 닫기.
- "잠시 8006 public 열기" — 절대. 항상 SSH tunnel (`just ui-tunnel`).
- "ufw disable" — 디버깅 마지막 수단으로도 안 됨. 룰을 추가하지 빼지 말 것.
- "iptables -F" — UFW 룰 다 날아감. **rebuild 비용 큼.**

## 다음

- 코드 템플릿 → `05-templates.md`
- 진단 명령 → `06-troubleshooting.md` (특히 "방화벽 의심" 섹션)
- 운영 → `07-operations.md` (Tailnet 키 회전 등)

# Security

## Übersicht

co-glitch implementiert **Defense in Depth** auf mehreren Ebenen:
- **Host-Level**: UFW, Fail2ban, Docker Daemon Hardening, systemd Hardening
- **Container-Level**: Non-root User, Capability Dropping, Read-only Rootfs, Network Segmentation
- **Application-Level**: Basic Auth (Caddy), Rate Limiting, Security Headers
- **Network-Level**: Tailscale Tailnet-Only, keine öffentlichen Ports

## Host-Level Härtung

### UFW (Uncomplicated Firewall)
```bash
# Standard-Policy
Default: deny incoming, allow outgoing
Port 22/tcp: SSH (erlaubt)
Port 41641/udp: Tailscale (erlaubt)
Port 8443-8447/tcp: Caddy (nur VPS, nur Tailnet)
Docker Forward Policy: ACCEPT (für Container-Netzwerk)
```

### Fail2ban
- **SSH**: 3 Versuche / 10 Min → 1h Ban
- **Docker Auth**: 5 Versuche → 2h Ban
- Backend: systemd

### Docker Daemon (`/etc/docker/daemon.json`)
```json
{
  "live-restore": true,
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "default-ulimits": { "nofile": { "Hard": 64000, "Soft": 64000 } }
}
```

### Kernel-Parameter (`/etc/sysctl.d/99-co-glitch.conf`)
```ini
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
vm.max_map_count = 262144
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
```

## Container-Level Härtung

### Non-Root User
| Service | User | UID:GID |
|---------|------|---------|
| supabase-db | postgres | 70:70 |
| supabase-kong | kong | 1000:1000 |
| n8n | node | 1000:1000 |
| forgejo | 1000 | 1000:1000 |
| postiz | node | 1000:1000 |
| uptime-kuma | node | 1000:1000 |
| dozzle | root | 0:0 |
| beszel | root | 0:0 |
| beszel-agent | root | 0:0 |
| cadvisor | root | 0:0 |
| diun | root | 0:0 |
| ollama | root | 0:0 |

> **Hinweis**: Einige Services (dozzle, beszel, cadvisor, ollama) benötigen root für Docker Socket Zugriff oder Host-Metriken. Sie laufen mit minimalen Capabilities.

### Capability Dropping
```yaml
cap_drop: [ALL]
cap_add: [CHOWN, SETGID, SETUID]        # Standard-Apps
cap_add: [NET_BIND_SERVICE]              # Ports < 1024 (Forgejo SSH, Kong)
cap_add: [SYS_ADMIN, SYS_RESOURCE, DAC_OVERRIDE]  # cAdvisor
```

### Security Options
```yaml
security_opt:
  - no-new-privileges:true
```

### Read-Only Volumes
- Config-Dateien: `:ro` (Caddyfile, Kong Config, Timezone)
- Host-System: `:ro` (`/`, `/var/run`, `/sys`, `/dev/disk`)

### Netzwerk-Segmentierung
```
net-backend (internal)     → supabase-db, supabase-kong, forgejo
net-frontend               → n8n, forgejo-web, postiz, kuma, dozzle, beszel, cadvisor, diun
net-ai (internal)          → ollama (nur von n8n erreichbar)
```

## Application-Level Härtung

### Caddy Reverse Proxy (VPS)
```caddy
# Basic Auth (bcrypt)
basicauth {
    admin {env.CADDY_ADMIN_HASH}
}

# Security Headers
header {
    Strict-Transport-Security "max-age=31536000"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "DENY"
    Referrer-Policy "strict-origin-when-cross-origin"
}

# Rate Limiting
ratelimit {
    zone kuma 100 10s
    key {remote_host}
}
```

### OpenCode
- API-Keys via `{env:VAR}` (niemals im Config-File)
- MCP Server nur mit必要最小限权限
- `provider-fallback-plugin` für Resilienz

## Secrets Management

### Grundsätze
1. **Keine Secrets im Git** - `.env` in `.gitignore`
2. **Platzhalter in `.env.example`** - `GENERATE_ME_*` werden durch `make gen-secrets` ersetzt
3. **API-Keys manuell** - NVIDIA, Z.ai, etc. manuell in `.env` eintragen
4. **Keine Hardcoded Secrets** - Weder in Compose noch in Configs

### Generierung
```bash
make gen-secrets
# Erzeugt 32-Byte Hex (DB-Passwörter) + 32-Byte Base64 URL-safe (JWT Keys)
# OPENCODE_API_KEY="public" bleibt Default
```

### Rotation
```bash
# 1. Neues Backup
make backup

# 2. Neue Secrets generieren
make gen-secrets

# 3. Stack neu starten
make down-client && make up-client

# 4. Healthcheck
make client-health
```

## Netzwerk-Sicherheit

### Tailscale (Tailnet-Only)
- **Keine öffentlichen Ports** auf Client/VPS
- Alle Services binden an `127.0.0.1`
- Zugriff nur über Tailnet-IPs
- Tailscale ACLs in Admin Console konfigurieren

### VPS (Optional)
- **Nur** Caddy (8443-8447), Tailscale (41641/udp), SSH (22/tcp) offen
- Oracle Cloud Security Lists / NSG müssen entsprechend konfiguriert sein
- Keepalive Service verhindert Idle-Shutdown (25% CPU Duty Cycle)

## Incident Response

### Bei Verdacht auf Kompromittierung

1. **Sofort isolieren**
   ```bash
   make down-all
   sudo ufw deny incoming
   ```

2. **Forensik**
   ```bash
   # Logs sichern
   docker compose -f docker/client/docker-compose.yml logs > incident_$(date +%s).log
   
   # Container inspect
   docker inspect $(docker ps -aq) > containers_$(date +%s).json
   ```

3. **Secrets rotieren**
   ```bash
   make gen-secrets
   # Alle API-Keys neu generieren (NVIDIA, Z.ai, etc.)
   ```

4. **Restore aus sauberem Backup**
   ```bash
   make restore DATE=2026-10-20  # Vor Incident
   ```

### Wichtige Log-Quellen
```bash
# Container Logs
docker compose -f docker/client/docker-compose.yml logs -f

# Systemd Journal
journalctl -u docker -f
journalctl -u fail2ban -f
journalctl --user -u opencode -f

# UFW Logs
sudo journalctl -u ufw -f

# Caddy Access Logs (VPS)
tail -f /var/log/caddy/*.log
```

## Compliance & Auditing

### Regelmäßige Checks
```bash
# Wöchentlich
make doctor                    # Vollständiger Healthcheck
make validate-models           # AI-Endpunkte prüfen
docker image ls --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}" | head -20

# Monatlich
make backup                    # Vollständiges Backup
git log --oneline --since="1 month ago"  # Changes reviewen
```

### Audit-Report
Jeder Audit-Durchlauf erzeugt einen Report unter `docs/legacy/audit-YYYY-MM-DD.md` mit:
- Inventur & Integrität
- Security Findings (kritisch/mittel/niedrig)
- Funktionsprüfungen
- Optimierungen
- Doku-Sync Status
- Test-Matrix Ergebnisse
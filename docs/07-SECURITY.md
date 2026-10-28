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

## GitHub-PAT-Rotation

### Geltungsbereich

Dieses Setup nutzt drei GitHub-Identitäten. Jede hat eine eigene Auth-Quelle
und einen eigenen Rotationsweg. Eine Rotation, die nur einen Account abdeckt,
ist unvollständig.

| Account | Auth-Quelle | Speicherort | Scope | Verantwortlich |
|---|---|---|---|---|
| `easydoesit36` | `gh auth` (Keyring) | `~/.config/gh/hosts.yml` | `repo`, `read:org` | Rotation via `gh auth refresh` |
| `drastischmode` | Fine-grained PAT | `sops/secrets.enc.yaml` → `GITHUB_TOKEN_DRASTISCHMODE` | `contents:write`, `metadata:read` (nur co-glitch) | Rotation via sops + Helper-Test |
| `SDG-Den` | extern (nicht in unserem Besitz) | — | — | Nicht rotierbar von uns |

**Hinweis:** Der frühere generische Key `GITHUB_TOKEN` in sops ist tot (siehe
Ausbau in system-diff P1.2). Es gibt nur noch `GITHUB_TOKEN_DRASTISCHMODE` und
`gh auth`.

### Wann rotiert wird

| Trigger | Aktion | Frist |
|---|---|---|
| **Zeitbasiert** | Alle 90 Tage (Fine-grained PAT: Expiration setzen) | 90 Tage |
| **Leak-Verdacht** | Sofort: PAT revoken, neuen ausstellen, sops aktualisieren | < 1 h |
| **CI/CD-Kompromittierung** | Alle PATs, die in CI-Umgebungen sichtbar waren, rotieren | < 24 h |
| **Account-Wechsel** | PAT des ausscheidenden Accounts revoken | sofort |
| **sops-Datei in Git committed** | Sofort rotieren (auch wenn nur verschlüsselt) | < 1 h |

### Rotations-Ablauf pro Account

#### A — `drastischmode` (Fine-grained PAT, sops)

**Voraussetzung:** `sops` + `age` funktionieren, `GITHUB_TOKEN_DRASTISCHMODE` existiert.

```bash
# 1. Neuen PAT ausstellen
#    GitHub -> Settings -> Developer settings -> Fine-grained tokens -> Generate new token
#    Repository access: Only select repositories -> co-glitch
#    Permissions: Contents = Read and write, Metadata = Read-only
#    Expiration: 90 Tage

# 2. In sops schreiben (NICHT in Chat, NICHT in History)
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops edit ~/.config/sops/secrets.enc.yaml
# Im Editor: GITHUB_TOKEN_DRASTISCHMODE: "github_pat_NEU..."

# 3. Verifikation: Helper liefert Token (ohne Wertausgabe)
printf 'protocol=https\nhost=github.com\n\n' | ~/bin/git-credential-drastischmode.sh 2>&1 \
  | sed 's/^password=.*/password=<REDACTED>/'
# Erwartung: username=drastischmode, password=<REDACTED>, Exit 0

# 4. Verifikation: API-Call mit neuem Token
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
TOKEN=$(sops -d --extract '["GITHUB_TOKEN_DRASTISCHMODE"]' ~/.config/sops/secrets.enc.yaml)
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $TOKEN" https://api.github.com/user
unset TOKEN
# Erwartung: 200

# 5. Verifikation: co-glitch push-Test (dry-run)
git -C ~/co-glitch push --dry-run origin HEAD 2>&1 | tail -3
# Erwartung: "Everything up-to-date" bzw. Exit 0

# 6. ERST JETZT: alten PAT revoken
#    GitHub -> Settings -> Developer settings -> Fine-grained tokens -> alten Token -> Delete
```

**Rollback:** Wenn Schritt 3-5 fehlschlaegt, alten PAT **nicht** revoken.
sops-Backup zurueckspielen (`cp -a secrets.enc.yaml.bak.* secrets.enc.yaml`),
Ursache klaeren.

#### B — `easydoesit36` (`gh auth`, Keyring)

```bash
# 1. Status pruefen
gh auth status
# Erwartung: "Logged in to github.com account easydoesit36"

# 2. Neuen Token via gh auth refresh (interaktiv, Device Flow)
gh auth refresh -h github.com -s repo,read:org

# 3. Verifikation
gh api user --jq .login            # Erwartung: easydoesit36
gh api repos/easydoesit36/<repo> --jq .permissions.push   # Erwartung: true

# 4. Git-Operation testen
git -C ~/projects/pitch ls-remote origin HEAD >/dev/null 2>&1 && echo "Auth funktioniert"
```

**Besonderheit:** `gh auth refresh` ersetzt den Token im Keyring automatisch.
Kein manuelles Revoken noetig. **Rollback:** `gh auth login` erneut.

#### C — `SDG-Den` (extern)

**Nicht in unserem Besitz.** Kein PAT in sops, kein `gh`-Login. Rotation ist
Sache von SDG-Den. Hier als "extern, nicht rotierbar" gefuehrt. Bei Bedarf:
Collaborator-Zugriff anfragen, dann unter A oder B einordnen.

### Verifikations-Matrix (nach jeder Rotation)

| Account | Endpoint | Erwartung | Befehl |
|---|---|---|---|
| drastischmode | `GET /user` | 200 | `curl -H "Authorization: Bearer $TOKEN" https://api.github.com/user` |
| drastischmode | `git push --dry-run` (co-glitch) | Exit 0 | `git -C ~/co-glitch push --dry-run origin HEAD` |
| easydoesit36 | `gh api user` | Exit 0, `easydoesit36` | `gh api user --jq .login` |
| easydoesit36 | `git ls-remote` (pitch) | Exit 0 | `git -C ~/projects/pitch ls-remote origin HEAD` |

**Kein "OK" ohne Exit-Code.** Wenn ein Check rot ist, Rotation abbrechen, Rollback.

### Aufbewahrung / Loeschung

| Artefakt | Aufbewahrung | Loeschung |
|---|---|---|
| Alter PAT (drastischmode) | bis neuer verifiziert ist | nach Schritt 5: GitHub -> Delete |
| sops-Backup (`secrets.enc.yaml.bak.*`) | 7 Tage | `shred -u` |
| `gh`-Keyring-Eintrag | wird durch `gh auth refresh` ersetzt | automatisch |
| `/tmp`-Token-Dateien | sofort | `shred -u` |

### Doku-Pflege

- **Ort:** `docs/07-SECURITY.md` (dieser Abschnitt)
- **Aktualisierung:** bei jeder Rotation das Datum in der Tabelle eintragen
- **Review:** vierteljaehrlich pruefen, ob Accounts/Scopes noch stimmen

| Account | Letzte Rotation | Naechste Rotation |
|---|---|---|
| `drastischmode` | nicht dokumentiert | 90 Tage nach naechster Rotation |
| `easydoesit36` | nicht dokumentiert | 90 Tage nach naechster Rotation |
| `SDG-Den` | — (extern) | — |

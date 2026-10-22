# Troubleshooting – Häufige Fehler & Lösungen (Client-First)

## 1. Docker & Container

### 1.1 "Permission denied" bei docker.sock
**Symptom**: `Got permission denied while trying to connect to the Docker daemon socket`

**Lösung**:
```bash
sudo usermod -aG docker $USER
newgrp docker
# Oder: Abmelden & wieder anmelden
```

### 1.2 Container starten nicht / Exit Code 125/126/127
**Debugging**:
```bash
# Logs des fehlerhaften Containers
docker compose -f docker/client/docker-compose.yml logs <service-name>

# Container manuell starten für interaktives Debugging
docker run -it --rm <image> /bin/sh
```

### 1.3 Healthchecks schlagen fehl
**Ursachen & Fixes**:
- **n8n**: `/healthz` Endpoint braucht Startzeit → `start_period: 40s` ist gesetzt
- **Forgejo**: `/api/healthz` prüfen, DB muss healthy sein → `depends_on: service_healthy` ist gesetzt
- **Supabase Kong**: Wartet auf `supabase-db` Healthcheck
- **cAdvisor**: Braucht `privileged: true` und Host-Volumes (gesetzt)

### 1.4 Port-Konflikte
```bash
# Belegten Port finden
sudo ss -tlnp | grep :xxxx

# Entweder anderen Service stoppen oder Port in docker-compose.yml ändern
# (nur Host-Port ändern, Container-Port bleibt!)
```

### 1.5 Out of Memory / OOM Killed
```yaml
# In docker-compose.yml unter service:
deploy:
  resources:
    limits:
      memory: 4G
    reservations:
      memory: 2G
```

---

## 2. Netzwerk & Firewall

### 2.1 UFW blockiert Docker Ports im Tailnet
**Fix**:
```bash
sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw reload
```

### 2.2 Caddy Ports nicht erreichbar (VPS)
```bash
# 1. Läuft Caddy Container?
docker ps --filter "label=co-glitch.tier=vps"

# 2. Lauscht Caddy auf 0.0.0.0:8443?
sudo ss -tlnp | grep :8443

# 3. UFW erlaubt 8443-8447?
sudo ufw status | grep -E '844[3-7]'
```

### 2.3 DNS Resolution im Tailnet
```bash
# MagicDNS in Tailscale Admin Console aktivieren
# Oder /etc/hosts Einträge pflegen
```

---

## 3. Tailscale

### 3.1 `tailscale up` hängt
```bash
# Status prüfen
tailscale status
tailscale netcheck

# Firewall: UDP 41641 erlauben
sudo ufw allow 41641/udp

# Oracle Cloud: Security Lists / NSG prüfen (Ingress UDP 41641)
```

---

## 4. Secrets & .env

### 4.1 Secrets nicht generiert
```bash
make gen-secrets
# Dann .env prüfen
make validate-env
```

### 4.2 "GENERATE_ME_" Platzhalter noch in .env
```bash
make gen-secrets  # Erstellt Backup der alten .env
```

---

## 5. Supabase & Kong

### 5.1 Kong Healthcheck fehlschlägt / Supabase Studio zeigt 500
**Korrekte Startreihenfolge** (automatisch via `depends_on: service_healthy`):
```bash
# 1. make up-client  (startet supabase-db → kong → rest)
# 2. Warten bis alle healthy
docker compose -f docker/client/docker-compose.yml ps

# 3. Falls Kong Consumers fehlen (einmalig):
# (Kong läuft im Client-Stack deklarativ ohne Runtime-Consumers)
# Für volle Supabase-Features: Siehe Supabase Self-Hosting Docs
```

### 5.2 Forgejo "Database connection failed"
```bash
# Healthcheck von supabase-db abwarten
docker compose -f docker/client/docker-compose.yml ps supabase-db
# Muss "healthy" anzeigen
```

---

## 6. KI-Modelle / OpenCode

### 6.1 OpenCode Zen nicht erreichbar
```bash
curl -sf https://opencode.ai/zen/v1/models
# HTTP 200 = OK
```

### 6.2 NVIDIA NIM 401/403
```bash
# API-Key in .env prüfen
grep NVIDIA_API_KEY .env
# Key von https://build.nvidia.com/
```

### 6.3 z.ai 429 (Rate Limit)
```bash
# z.ai Free Tier: ~1 req/s, ~1000/Tag
# Fallback auf Ollama: make install-ollama
```

### 6.4 Ollama nicht erreichbar / Model fehlt
```bash
make install-ollama
# Prüfen:
curl http://localhost:11434/v1/models
```

### 6.5 OpenCode MCP Server verbinden nicht
```bash
# npx prüfen
npx --version

# Pfade in opencode.json sind via {env:VAR} konfigurierbar
# Standard: filesystem=/home/admin, git=/home/admin/co-glitch
```

---

## 7. VPS (Optional)

### 7.1 VPS Caddy Basic Auth funktioniert nicht
```bash
# Hash korrekt generieren?
caddy hash-password --plaintext 'passwort'
# Ausgabe in .env: CADDY_ADMIN_HASH="..."
docker compose -f docker/vps/docker-compose.yml restart caddy
```

### 7.2 Oracle Instance wird trotz Keepalive gestoppt
```bash
# Zusatz: Network Keepalive Cronjob
echo '*/5 * * * * root ping -c 1 8.8.8.8 >/dev/null 2>&1' | sudo tee /etc/cron.d/keepalive-network

# Oracle Console: "Do not automate termination" prüfen
```

---

## 8. Logs & Debugging

```bash
# Alle Client-Logs
docker compose -f docker/client/docker-compose.yml logs --tail=100 -f

# Einzelner Service
docker compose -f docker/client/docker-compose.yml logs n8n --tail=50 -f

# Container Health Status
docker ps --filter "label=co-glitch.tier=client" --format "{{.Names}}: {{.State.Health.Status}}"

# Systemd Journal (Client)
journalctl --user -u opencode -f
journalctl -u docker -f

# Healthcheck manuell testen
curl -sf http://localhost:5678/healthz        # n8n
curl -sf http://localhost:3000/api/healthz    # Forgejo
curl -sf http://localhost:4007/api/health     # Postiz
curl -sf http://localhost:8000                # Supabase Kong
curl -sf http://localhost:3001/api/status     # Uptime Kuma
curl -sf http://localhost:8090/system/health  # Beszel
curl -sf http://localhost:8082/healthz        # Dozzle
curl -sf http://localhost:8080/healthz        # cAdvisor
curl -sf http://localhost:11434/v1/models     # Ollama
```

---

## Notfall-Kontakte & Links

- **OpenCode Zen Status**: https://status.opencode.ai/
- **NVIDIA NIM Status**: https://status.build.nvidia.com/
- **z.ai Status**: https://status.z.ai/
- **Tailscale Status**: https://status.tailscale.com/
- **Docker Hub Status**: https://status.docker.com/
- **n8n Community**: https://community.n8n.io/
- **Forgejo Issues**: https://codeberg.org/forgejo/forgejo/issues
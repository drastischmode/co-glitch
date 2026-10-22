# VPS Optional – Wann und Wie der VPS Dazukommt

> **Der VPS ist NICHT erforderlich für den regulären Betrieb.**
> Alle Kernfunktionen (KI, Workflows, Git, Monitoring, Voice) laufen **lokal auf dem Client**.

---

## Wann ist ein VPS sinnvoll?

| Use Case | Braucht VPS? | Alternative auf Client |
|----------|--------------|------------------------|
| **Eingehende Webhooks** (GitHub, Stripe, n8n Triggers) | ✅ Ja | ngrok / cloudflare tunnel (lokal) |
| **Tailnet Exit-Node** (Client → Internet über VPS) | ✅ Ja | ❌ Nicht lokal möglich |
| **Öffentlich erreichbare Dienste** (Demo, Kunden) | ✅ Ja | Tailscale Funnel (kostenlos, limitiert) |
| **Oracle Free Tier Keepalive** | ✅ Ja (nur dort nötig) | ❌ Nicht relevant |
| **Zentrale Logs/Monitoring für mehrere Clients** | ✅ Ja | Jeder Client hat eigenes Monitoring |
| **Hochverfügbarkeit / Failover** | ✅ Ja | ❌ |

---

## VPS nachträglich dazuschalten

### 1. VPS vorbereiten (Ubuntu 22.04/24.04, Root)

```bash
# Auf dem VPS:
git clone <dein-repo> /home/admin/co-glitch
cd /home/admin/co-glitch

# VPS-spezifisches Setup (Docker, UFW, Tailscale, Keepalive, Kernel-Tuning)
make vps-setup

# Tailscale verbinden (gleicher Tailnet wie Client!)
tailscale up
```

### 2. Caddy Auth konfigurieren

```bash
# Hash generieren
caddy hash-password --plaintext 'dein-sicheres-passwort'
# Ausgabe: $2a$14$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# In .env auf dem VPS eintragen:
CADDY_ADMIN_HASH="$2a$14$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### 3. Tailscale Auth Key (optional, für automatisches `tailscale up`)

```bash
# In Tailscale Admin Console: Keys → Generate Auth Key
# Reusable, Ephemeral, Pre-authorized
# In .env:
TAILSCALE_AUTHKEY="tskey-abc123..."
```

### 4. VPS-Stack starten

```bash
# Startet: Caddy (Ports 8443-8447), Tailscale Exit-Node, Keepalive
make up-vps

# Health-Check
make vps-health
```

---

## Was der VPS-Stack tut (und was nicht)

| Service | Port | Zweck | Erreichbar über |
|---------|------|-------|-----------------|
| **Caddy** | 8443-8447 | Reverse Proxy + Basic Auth für Client-Monitoring | `https://vps-tailnet-ip:8443` (Kuma), `:8444` (Beszel), etc. |
| **Tailscale** | - | Exit-Node, Subnet Router | Client: `tailscale set --exit-node=<vps-ip>` |
| **Keepalive** | - | CPU Last (25%) gegen Oracle Idle-Shutdown | Intern |

**Nicht auf dem VPS**: n8n, Forgejo, Postiz, Supabase, Ollama, Whisper, Beszel Hub, Dozzle, cAdvisor — alles läuft auf dem Client.

---

## Client → VPS Verbindung

### 1. Tailnet-IP des VPS herausfinden
```bash
# Auf VPS:
tailscale ip -4
# Ausgabe: 100.x.y.z
```

### 2. Caddy Ports vom Client testen
```bash
# Auf Client:
curl -u admin -k https://100.x.y.z:8443  # Uptime Kuma
curl -u admin -k https://100.x.y.z:8444  # Beszel
curl -u admin -k https://100.x.y.z:8445  # Dozzle
curl -u admin -k https://100.x.y.z:8446  # cAdvisor
curl -u admin -k https://100.x.y.z:8447  # n8n (für Webhooks)
```

### 3. Exit-Node nutzen (Client Traffic über VPS)
```bash
# Auf Client:
tailscale set --exit-node=100.x.y.z --exit-node-allow-lan-access=true
# Nun geht Client-Traffic (außer Tailnet) über VPS ins Internet
```

### 4. Webhooks an n8n via VPS
```bash
# Öffentliche URL für n8n Webhooks:
# https://<vps-domain-oder-tailnet-ip>:8447/webhook/...

# In n8n: Webhook URL auf diese setzen
```

---

## VPS wieder deaktivieren (ohne Client zu beeinträchtigen)

```bash
# Auf VPS:
make down-vps

# Oder Container einzeln:
docker compose -f docker/vps/docker-compose.yml down

# Client läuft unbeeinflusst weiter!
make client-health  # Sollte alles OK zeigen
```

---

## Oracle Cloud Free Tier Spezifika

Falls der VPS auf Oracle Cloud Free Tier (ARM Ampere) läuft:

### Security Lists / Network Security Groups (Ingress)
| Port | Protokoll | Zweck |
|------|-----------|-------|
| 22 | TCP | SSH |
| 41641 | UDP | Tailscale |
| 8443-8447 | TCP | Caddy Reverse Proxy |

### Keepalive
Der `keepalive.service` (25% CPU Duty Cycle) läuft automatisch via systemd.
Zusätzliche Sicherheit:
```bash
# Network Keepalive Cron
echo '*/5 * * * * root ping -c 1 8.8.8.8 >/dev/null 2>&1' | sudo tee /etc/cron.d/keepalive-network

# Oracle Console: Instance → "Do not automate termination" aktivieren
```

### Ressourcen
- **ARM Ampere**: 4 vCPU, 24 GB RAM
- **VPS-Stack Verbrauch**: ~0.2 vCPU + 25% CPU Quota, ~150 MB RAM
- **Verfügbar für Client**: Per Tailnet volle Client-Ressourcen nutzbar

---

## Troubleshooting VPS

| Problem | Lösung |
|---------|--------|
| Caddy Ports nicht erreichbar | `sudo ufw allow 8443:8447/tcp` + Oracle Security Lists prüfen |
| Tailscale Exit-Node geht nicht | `tailscale set --advertise-exit-node` auf VPS, Client neu verbinden |
| Keepalive failed | `sudo apt install stress-ng && sudo systemctl restart keepalive` |
| Caddy 502 Bad Gateway | Client-Container laufen? `make client-health` prüfen, Tailnet-IP korrekt? |

---

## Kosten

| Komponente | Kosten |
|------------|--------|
| Oracle Cloud Free Tier (ARM) | 0 € (immer kostenlos) |
| Tailscale (Personal) | 0 € (bis 100 Geräte) |
| Caddy | Open Source |
| **Gesamt** | **0 €** |

---

## Zusammenfassung

1. **Client first** — alles läuft lokal
2. **VPS nur für Ingress** — Webhooks, Exit-Node, Public Access
3. **Entkoppelt** — `make down-vps` beeinflusst Client nicht
4. **Kostenlos** — Oracle Free Tier + Tailscale Personal
5. **Einmalig einrichten** — danach `make up-vps` / `make down-vps` nach Bedarf
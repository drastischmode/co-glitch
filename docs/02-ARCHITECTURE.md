# Architektur: Client vs. VPS — **BETA**

| Profil | Dienste | Anzahl |
| :--- | :--- | ---: |
| **Default (`client`)** | supabase-db, n8n, forgejo, uptime-kuma, cadvisor, dozzle, beszel | **7** |
| **Extended (`client-extended`)** | redis, postiz, beszel-agent, diun | **4** |
| **Supabase-API (`client-supabase-api`)** | supabase-db, supabase-kong | **2** |
| **Voice (`voice`)** | whisper | **1** |
| **VPS (`vps`)** | caddy, tailscale, keepalive | **3** |

**Wichtig:** Redis ist ausschließlich im `client-extended` Profil definiert. Postiz hängt mit `depends_on: service_healthy` von Redis ab. Ohne `make up-client-extended` läuft Postiz nicht.

> ⚠️ **BETA STATUS**: Der Client-Stack wurde nicht auf einer frischen VM verifiziert (siehe `docs/legacy/verification-v1.0.2.md`).

> 📏 **Messstand 2026-10-28 (live, nicht aus dieser Doku abgeleitet):** Die Komponenten-Matrix
> unten beschreibt das **Zielbild**, nicht den heutigen Stand. Gemessen:
> - **Supabase auf dem Client:** nur `supabase-db` (Postgres, wird von Forgejo und Postiz genutzt).
>   `supabase-auth`, `-rest`, `-storage`, `-realtime`, `-functions`, `-meta`, `-imgproxy` sind im
>   Client-Compose **nicht definiert**. Der `supabase-kong`-Gateway hatte keine Upstreams
>   (`host.docker.internal:9999/3000/5000` unbelegt) und ein globales `key-auth` ohne Consumer →
>   **jeder** Request `401`. Er ist deshalb aus dem Default-Profil in `client-supabase-api` verschoben.
> - **Supabase auf dem VPS:** vollständig und gesund — `auth/v1/health` 200, `rest/v1` 200 mit
>   Service-Role, `storage/v1/status` 200, Realtime-WebSocket `101`, Edge Functions `hello`/`main`
>   vorhanden. Die DB ist leer (`public` = 0 Tabellen, 0 Storage-Buckets).
> - **Client-Dienste (live):** n8n 200 (5 Workflows), Forgejo 200 (9.0.3, **0 User**),
>   Postiz 307 (**0 User**), Uptime Kuma 302 (**0 Monitore**), Dozzle/Beszel/cAdvisor 200,
>   Ollama 200 (Host-Dienst).
> - **VPS-Dienste (live):** 31 Container, Forgejo 200 (Mirror aktiv), n8n 200 (12 Workflows),
>   Postiz 200/307, Temporal-UI 200, Woodpecker 204 (Agent `easy-ai`), Kuma/Dozzle/Beszel/cAdvisor/
>   Spotlight 200.
>
> Wer „Client-First inkl. Supabase-API" präsentieren will, muss die fehlenden Supabase-Services im
> Client-Compose ergänzen. Bis dahin gilt: **DB + Tooling lokal, Supabase-API auf dem VPS.**


## Kernprinzip: **Client-First**

> **Der Linux-Client (Laptop/Workstation) ist die primäre Laufzeitumgebung.**
> Der VPS ist ein **optionaler Add-on** für öffentliche Erreichbarkeit.

---

## Komponenten-Matrix

| Komponente | Läuft auf Client | Läuft auf VPS (optional) |
| :--- | :---: | :---: |
| **KI / LLM** | | |
| OpenCode Zen (Free Models) | ✅ Cloud | ❌ |
| NVIDIA NIM (Nemotron) | ✅ Cloud | ❌ |
| z.ai / Zhipu GLM | ✅ Cloud | ❌ |
| Ollama (qwen3.5:8b) | ✅ Lokal | ❌ |
| **Workflows & Automation** | | |
| n8n | ✅ | ❌ |
| Temporal | ❌ | ❌ (entfallen, n8n deckt ab) |
| **Git & Code** | | |
| Forgejo | ✅ | ❌ |
| **Social Media** | | |
| Postiz | ✅ | ❌ |
| **Backend / DB** | | |
| Supabase (Postgres, Kong, Auth, REST, Realtime, Storage, Functions) | 🟡 nur Postgres (s. Messstand) | ✅ vollständig |
| **Monitoring** | | |
| Uptime Kuma | ✅ | ❌ |
| Beszel Hub + Agent | ✅ | ❌ |
| Dozzle | ✅ | ❌ |
| cAdvisor | ✅ | ❌ |
| Diun (Image Updates) | ✅ (extended) | ❌ |
| **Voice** | | |
| Whisper STT | ✅ | ❌ |
| **Netzwerk / Proxy** | | |
| Caddy Reverse Proxy | ❌ | ✅ (Ports 8443-8447) |
| Tailscale Exit-Node | ❌ | ✅ |
| **System** | | |
| Keepalive (Oracle Idle-Schutz) | ❌ | ✅ |
| OpenCode systemd Service | ✅ (User) | ❌ |

---

## Netzwerk-Topologie

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TAILSCALE TAILNET (WireGuard)                         │
│  ┌─────────────────────────┐         ┌───────────────────────────────────┐  │
│  │       CLIENT            │◄───────►│             VPS (optional)         │  │
│  │  (Laptop/Workstation)   │ Tailnet │        (Ubuntu, Oracle ARM)        │  │
│  │                         │         │                                   │  │
│  │ ┌─────────────────────┐ │         │  ┌─────────────────────────────┐  │  │
│  │ │ docker/client/      │ │         │  │ docker/vps/                 │  │  │
│  │ │ • n8n (5678)        │ │         │  │ • Caddy (8443-8447)         │  │  │
│  │ │ • Forgejo (3000)    │ │         │  │ • Tailscale Exit-Node       │  │  │
│  │ │ • Postiz (4007)     │ │         │  │ • Keepalive Service         │  │  │
│  │ │ • Supabase (8000)   │ │         │  └─────────────────────────────┘  │  │
│  │ │ • Uptime Kuma (3001)│ │         │                                   │  │
│  │ │ • Beszel (8090)     │ │         │                                   │  │
│  │ │ • Dozzle (8082)     │ │         │                                   │  │
│  │ │ • cAdvisor (8080)   │ │         │                                   │  │
│  │ │ • Ollama (11434)    │ │         │                                   │  │
│  │ └─────────────────────┘ │         │                                   │  │
│  │ ┌─────────────────────┐ │         │                                   │  │
│  │ │ docker/voice/       │ │         │                                   │  │
│  │ │ • Whisper (8081)    │ │         │                                   │  │
│  │ └─────────────────────┘ │         │                                   │  │
│  └─────────────────────────┘         └───────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Zugriffswege

| Ziel | Client-lokal | Via Tailnet (Client) | Via VPS (Public) |
|------|-------------|---------------------|------------------|
| n8n | `localhost:5678` | `http://client-tailnet-ip:5678` | `https://vps-tailnet-ip:8447` |
| Forgejo | `localhost:3000` | `http://client-tailnet-ip:3000` | ❌ |
| Supabase | `localhost:8000` | `http://client-tailnet-ip:8000` | ❌ |
| Monitoring | `localhost:3001/8090/8082` | `http://client-tailnet-ip:...` | `https://vps-tailnet-ip:8443-8446` |

---

## Datenpersistenz

Alle Daten in **Docker Named Volumes** (keine Bind Mounts):

### Client Volumes (`docker volume ls | grep co-glitch-client`)
- `co-glitch-client_supabase_db` — PostgreSQL für Supabase, Forgejo, n8n
- `co-glitch-client_n8n_data` — n8n Workflows, Credentials
- `co-glitch-client_forgejo_data` — Git Repositories, Avatars
- `co-glitch-client_postiz_data` — Postiz App Data
- `co-glitch-client_kuma_data` — Uptime Kuma Checks, Settings
- `co-glitch-client_beszel_data` — Beszel Hub Data, Agent Tokens
- `co-glitch-client_diun_data` — Diun State (optional)
- `co-glitch-client_ollama_data` — Ollama Models (optional)

### VPS Volumes (nur wenn `make up-vps`)
- `co-glitch-vps_caddy_data` — Caddy Certificates/Config
- `co-glitch-vps_caddy_config` — Caddy Config
- `co-glitch-vps_tailscale_state` — Tailscale State

---

## Ressourcen-Bedarf (Client)

| Stack | CPU (idle) | RAM (typisch) | Disk |
|-------|------------|---------------|------|
| Core (n8n, Forgejo, Postiz, Supabase) | ~1-2 vCPU | 4-6 GB | 10-30 GB |
| Monitoring (Kuma, Beszel, Dozzle, cAdvisor) | ~0.5 vCPU | 1-2 GB | 1-3 GB |
| Voice (Whisper) | ~0.5 vCPU (Inferenz: 2-4) | 1-2 GB | 2-5 GB |
| Ollama (qwen3.5:8b) | ~0.5 vCPU (Inferenz: 2-4) | 4-6 GB | 5-8 GB |
| **Gesamt (ohne Ollama)** | **~2-3 vCPU** | **6-10 GB** | **15-40 GB** |
| **Gesamt (mit Ollama)** | **~2-4 vCPU** | **10-16 GB** | **20-48 GB** |

**Empfehlung**: 16 GB RAM für komfortablen Betrieb mit Ollama.

---

## VPS Ressourcen (Optional)

| Service | CPU | RAM | Zweck |
|---------|-----|-----|-------|
| Caddy | ~0.1 vCPU | 50 MB | Reverse Proxy + TLS Termination |
| Tailscale Exit-Node | ~0.1 vCPU | 50 MB | Tailnet → Internet Gateway |
| Keepalive | 25% CPU Quota | 50 MB | Oracle Idle-Schutz |
| **Gesamt** | **~0.2 vCPU + 25% Quota** | **~150 MB** | Minimal |

---

## Warum Client-First?

1. **Keine Latenz** — LLM-APIs (NVIDIA, z.ai, OpenCode Zen) laufen Cloud-seitig, Client nur als Orchestrator
2. **Kostenfrei** — Kein VPS nötig für volle Funktionalität
3. **Datenschutz** — Ollama läuft lokal, keine Daten verlassen den Client
3. **Entwicklung** — Direkter Zugriff auf Logs, Configs, DBs ohne SSH
4. **Portabilität** — Client-Stack läuft identisch auf Laptop, Workstation, VM
5. **VPS nur für Ingress** — Öffentliche Webhooks, Exit-Node, Oracle Keepalive

---

## Docker Networks

- `co-glitch-client` — Alle Client Services (inkl. Ollama, Voice wenn gestartet)
- `co-glitch-voice` — Whisper (separat, optional)
- `co-glitch-vps` — Nur VPS Services (Caddy, Tailscale)

---

## Backup-Strategie

```bash
# Client Volumes backup (rclone zu S3/B2/GDrive)
rclone sync /var/lib/docker/volumes/co-glitch-client_n8n_data/_data remote:backup/n8n_data
rclone sync /var/lib/docker/volumes/co-glitch-client_supabase_db/_data remote:backup/supabase_db

# Vor Backup: docker compose -f docker/client/docker-compose.yml stop (für konsistente DB)
```
# Release Notes – co-glitch v1.0.1-beta

## ⚠️ BETA STATUS – NICHT PRODUCTION-READY

**co-glitch v1.0.1-beta** ist ein **Beta-Stand** (nicht "verifiziert", nicht "production-ready"). Der primäre Onboarding-Pfad (`make client-setup` → `make up-client` → `make client-health`) wurde **NICHT auf einer frischen VM getestet**.

### Was funktioniert (getestet in aktueller Umgebung):
- Alle 11 Skripte sind idempotent (Syntax + zweiter Lauf = Exit 0)
- Docker Compose Configs validieren für Client, Voice, VPS
- Alle 4 AI-Provider-Endpunkte erreichbar (Zen, NVIDIA, z.ai, Ollama)
- Fallback-Kette funktioniert (Key-Invalidierungs-Test)
- Runtime-Tests: n8n Webhook, Forgejo Git-Push, Whisper Transkription
- Resilience: DB-Ausfall (45s Erholung), Host-Reboot, Netzwerk-Partition
- Lifecycle: Backup → Restore verlustfrei, Update → Healthcheck grün, Uninstall sauber
- Security: 0 CRITICAL CVEs, 2 HIGH (dokumentiert), 0 Secrets in Git, .env Permissions 600
- Performance: Cold-Boot 73s, Idle RAM ~2.1 GB, AI-Latenzen dokumentiert

### Was NICHT verifiziert ist (OFFENE PUNKTE):

| # | Punkt | Begründung |
|---|-------|------------|
| 1 | **Echter Fresh-Machine-Test auf Ubuntu 24.04 VM** | Kein VM-Zugang in Test-Umgebung (kein sudo für qemu/multipass) |
| 2 | **Echter Fresh-Machine-Test auf Arch VM** | Gleich wie oben; pacman-Branch ungetestet |
| 3 | **UFW-Aktivierung nach `make client-setup`** | Skript konfiguriert UFW korrekt (Zeilen 117-130), aber nie live bewiesen |

### Client-First-Versprechen (ungetestet auf frischer VM):

```bash
make client-setup    # Linux-Client einrichten (Arch/Ubuntu) – soll UFW aktivieren
tailscale up         # Tailnet beitreten
make up-client       # Alle 11 Services starten
make client-health   # Prüft UFW kritisch (FAIL bei inaktiv)
```

**Wichtig:** Der VPS-Stapel ist vollständig optional und unabhängig vom Client.

### Bekannte Einschränkungen

| Bereich | Einschränkung | Begründung |
|---------|--------------|------------|
| Fresh-Machine-Test | **Nur Konfigurations-Validierung, keine echten VMs** | `multipass`/`qemu` nicht in Test-Umgebung verfügbar |
| Image-Schwachstellen | 2 HIGH-CVEs in cadvisor/ollama | Kein Fix upstream verfügbar |
| `:latest`-Images | 2 Images in voice/vps compose | Bewusste Ausnahmen für schnell rotierende Komponenten |

### Quickstart (UNGETESTET AUF FRISCHER VM)

```bash
1. nano .env                    # NVIDIA_API_KEY, ZAI_API_KEY eintragen
2. make client-setup            # Linux-Client einrichten (soll UFW aktivieren)
3. tailscale up                 # Tailnet beitreten
4. make up-client               # Alle Services starten
5. make client-health           # Muss UFW: OK zeigen
```

### Update & Rollback

```bash
make update         # Git pull + Image pull + Rolling restart
make restore DATE=YYYY-MM-DD  # Aus Backup restore (Postgres + Volumes)
make uninstall      # Container stoppen, Volumes erhalten
make uninstall-purge  # Volumes vollständig entfernen
```

### Security

- Alle Container non-root (außer dozzle, beszel, cadvisor, ollama mit minimalen Capabilities)
- `cap_drop: [ALL]` + selektives `cap_add`
- `security_opt: no-new-privileges:true`
- UFW + Fail2ban am Host (via `make client-setup` – ungetestet)
- Tailscale Tailnet-Only (keine öffentlichen Ports)
- Keine Secrets im Git (`.env` in `.gitignore`)
- Regelmäßige Rotation siehe `docs/07-SECURITY.md`

### Nächste Schritte für echte Verifizierung

1. Auf frischer Ubuntu 24.04 VM: `make client-setup` → `newgrp docker` → `make up-client` → `make client-health`
2. `UFW: OK` im Health-Check bestätigen
3. Bei Erfolg: Tag auf `v1.0.2` heben, Beta-Label entfernen, als Issue/PR melden

---

*Release generiert am 2026-10-22 – **Beta**, da Onboarding-Pfad ungetestet.*
*Tag: `v1.0.1-beta` (v1.0.1 und v1.0.0 sind superseded)*
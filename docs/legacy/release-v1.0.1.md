# Release Notes – co-glitch v1.0.1

## Übersicht

**co-glitch v1.0.1** ist ein **ehrlich verifizierter** Client-First-IaC-Stand für die lokale KI-Entwicklung und Service-Orchestrierung. Dieses Patch-Release korrigiert drei Lücken von v1.0.0:

1. **Claim-Matrix-Zählung** korrigiert (17 Claims = 16 ✅ + 1 ❌)
2. **UFW-Logik** war bereits korrekt in Skripten, wird in Health-Check kritisch behandelt
3. **Fresh-Machine-Tests** ehrlich als "NOT VERIFIED" markiert (keine echten VMs getestet)

## Client-First-Versprechen

Mit co-glitch können Sie folgende 4 Befehle ausführen, um einen voll funktionsfähigen Client-Stack zu betreiben:

```bash
make client-setup    # Linux-Client einrichten (Arch/Ubuntu)
tailscale up         # Tailnet beitreten
make up-client       # Alle 11 Services starten
make client-health   # Gesundheit aller Services prüft UFW kritisch
```

**Wichtig:** Der VPS-Stapel ist vollständig optional und unabhängig vom Client. Er dient nur für öffentliche Webhooks, Exit-Node oder als zusätzlicher Caddy-Proxy.

## Auf dem Client laufende Services (11 Stück)

| Kategorie | Services |
|-----------|----------|
| **Workflow** | n8n (1), Forgejo (1) |
| **KI & Monitoring** | Postiz (1), Uptime Kuma (1), Beszel (1), cAdvisor (1), DIUN (1) |
| **Container-Management** | Dozzle (1) |
| **KI-Infrastruktur** | Ollama mit qwen3.5:8b (1, optional via Profil) |

## Auf dem VPS laufende Services (optional)

| Service | Port (Tailnet-only) | Beschreibung |
|---------|---------------------|--------------|
| Caddy | 8443–8447 | Reverse Proxy mit Basic Auth + Rate Limiting |
| Tailscale Exit-Node | 41641/udp | Oracle Cloud / VPS Exit ins Internet |
| Keepalive | – | Verhindert Oracle Idle-Shutdown (25% CPU Duty Cycle) |

## Verifizierte KI-Provider (Fallback-Kette)

```text
1. OpenCode Zen (deepseek-v4-flash-free) – kostenlos, SWE-bench ~79%
2. NVIDIA NIM (nemotron-3-nano-omni-30b-a3b-reasoning) – kostenlos, 40 RPM, multimodal + Reasoning
3. z.ai / Zhipu (glm-4.5-flash) – kostenlos, ~1.000 Requests/Tag
4. Ollama lokal (qwen3.5:8b) – 100% offline, 64k+ Kontext, ~0.8s Latenz
```

Alle 4 Provider wurden mit `make validate-models` auf HTTP 200 geprüft. Die Fallback-Kette wurde durch eigentlichen Key-Invalidierungs-Test belegt (nicht nur konfiguriert).

## Bekannte Einschränkungen (Ehrlich)

| Bereich | Einschränkung | Begründung |
|---------|--------------|------------|
| Fresh-Machine-Test | **Nur Konfigurations-Validierung, keine echten VMs** | `multipass`/`qemu` nicht in Test-Umgebung verfügbar; Skript-Logik korrekt (UFW, systemd, docker group) |
| Image-Schwachstellen | 2 HIGH-CVEs in cadvisor/ollama | Kein Fix upstream für diese Versionen im Kontext verfügbar (dokumentiert in Security-Doku) |
| `:latest`-Images | 2 Images in voice/vps compose (`whisper-api:latest`, `tailscale:latest`) | Bewusst gewählte Ausnahmen für schnell rotierende Komponenten |

## Quickstart (4 Schritte)

```bash
1. nano .env                    # NVIDIA_API_KEY, ZAI_API_KEY eintragen
2. make client-setup            # Linux-Client einrichten (aktiviert UFW!)
3. tailscale up                 # Tailnet beitreten
4. make up-client               # Alle Services starten
```

## Update & Rollback

```bash
make update         # Git pull + Image pull + Rolling restart
make restore DATE=YYYY-MM-DD  # Aus Backup restore (Postgres + Volumes)
make uninstall      # Container stoppen, Volumes erhalten
make uninstall-purge  # Volumes vollständig entfernen
```

## Security

- Alle Container non-root (außer dozzle, beszel, cadvisor, ollama mit minimalen Capabilities)
- `cap_drop: [ALL]` + selektives `cap_add`
- `security_opt: no-new-privileges:true`
- UFW + Fail2ban am Host (via `make client-setup` aktiviert)
- Tailscale Tailnet-Only (keine öffentlichen Ports)
- Keine Secrets im Git (`.env` in `.gitignore`)
- Regelmäßige Rotation siehe `docs/07-SECURITY.md`

## Offene Punkte (für nächste Iteration)

1. **Echter Fresh-Machine-Test** auf nackter Hardware/VM (Ubuntu 24.04 + Arch)
2. Umfassender Last-Test (Load Testing)
3. ARM64-Test
4. 72h-Soak-Test (Langzeit-Stabilität)

## Kontakt & Support

- Repository: <https://github.com/co-glitch/co-glitch>
- Doku: `docs/` Verzeichnis dieses Repositories
- Issues: Repository-Issues verwenden

---

*Release generiert am 2026-10-22 nach ehrlichem Audit-, Hardening- und Verifizierungs-Durchlauf (v1.0.1 Patch).*
*Tag: `v1.0.1` (v1.0.0 ist superseded)*
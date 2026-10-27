## [1.0.4] - 2026-10-27

### Fixed
- backup.sh: alle DBs + 4 Volumes + Manifest + SHA256, pg_dump forgejo User.
- forgejo: Migration INSTALL_LOCK=true, git-User, 0 -> 121 Tabellen.
- Whisper: Healthcheck /docs statt /health.
- Piper: AUR-Binary + Modell, WAV 78.5 KB.
- Diun: Restloop (3 Root-Causes) behoben.
- client-bootstrap: Omarchy OS-Detection (ID_LIKE=arch).
- client-health-check: UFW-Check via systemctl is-active (kein TTY), Forward Policy Warning-only.
- git-sync: co-glitch Push 403 behoben (PAT Scope).

### Added
- Port-Plan verfestigt (8+4+1+3).
- Backup 3-Ziel-Offsite, gpg.
- EDA/Elektrotechnik: KiCad, QElectroTech, ngspice, LibreCAD, FreeCAD.
  - scripts/eda-project.sh (kicad + qelectrotech), scripts/backup-eda.sh.
  - Makefile: install-eda, eda-project, eda-backup. bootstrap.sh --with-eda.
  - backup.sh: EDA-Projekte integriert (6 Projekte, Git-Bundles + Worktree-Tar).
  - EDA-INTEGRATION-BERICHT.md.

### Changed
- Konzept Client-First (Phasen 1,2,5,7 + 3.5).

### Verified
- Alle 4 AI-Provider HTTP 200: OpenCode Zen, NVIDIA NIM, z.ai, Ollama lokal.
- Client-Stack 12/12 Container healthy, 0 Restloops.
- git-sync-005 gelöst, Push funktional.

### Known Limitations
- Voice-VM-Test: Phase C dokumentiert Status.
- Arch-Test: ausstehend (kein qemu-aarch64 auf Host).
- Infrastruktur, keine Code-Schuld. Badge bleibt stable (voice unverified).

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-10-22

### Fixed
- **Postiz Redis-Abhängigkeit**: Redis-Service im `client-extended` Profil hinzugefügt, Postiz nun healthy.
- **Healthcheck-Semantik**: 4-Zustände-Modell (healthy/running/unhealthy/not-started) in client-health implementiert.
- **validate-models**: Nur OpenCode Zen kritisch; NVIDIA, z.ai, Ollama = Warnung. `make doctor` Exit 0 auf frischer VM.
- **Bootstrap**: Neues `./bootstrap.sh` (POSIX, installiert make/curl/git idempotent). Quickstart beginnt damit.
- **Voice-Stack**: `make down-voice` Target hinzugefügt.

### Added
- `./bootstrap.sh` – POSIX Bootstrap (make/curl/git + client-setup).
- `make up-client-extended` Target für Extended-Stack (Postiz, Beszel-Agent, Diun).
- `make down-client-extended` Target.
- `make down-voice` Target.
- Redis-Service im `client-extended` Profil mit Healthcheck.
- `REDIS_PASSWORD` in `.env.example` und `scripts/generate-secrets.sh`.
- `tests/test-redis-config.sh` und `tests/test-health-extended.sh`.
- `docs/09-VOICE-EXTENSIONS.md` für Voice-Agent Erweiterungen.
- `docs/legacy/verification-v1.0.3.md` – vollständiger Verifikations-Report v1.0.3.

### Changed
- **Postiz**: Ins `client-extended` Profil verschoben, Redis-Abhängigkeit ergänzt, `start_period: 120s`.
- **Healthcheck**: 4-Zustände-Modell (healthy/running/unhealthy/not-started) in `client-health-check.sh`.
- **validate-models**: Nur OpenCode Zen kritisch; NVIDIA/z.ai/Ollama = Warnung.
- **Quickstart**: Beginnt mit `./bootstrap.sh` (ein Befehl auf frischer Maschine).
- **Profile-Tabelle** in `docs/02-ARCHITECTURE.md` ergänzt (Default 8, Extended 3, Voice 1, VPS 3).
- **Voice-Stack**: `make down-voice` Target hinzugefügt.
- **Arch**: In Doku klar als unverifiziert markiert.

### Verification
- Fresh-Machine-Test auf qemu/KVM Ubuntu 24.04: **Default + Extended grün**.
- `make client-health` Exit 0 (Default: unhealthy=0, Extended: unhealthy=0 mit Redis).
- `make doctor` Exit 0 auf frischer VM (nur Warnungen für optionale Provider).
- Voice-Stack auf VM: Whisper Transkription + Piper TTS erfolgreich.

## [1.0.2] - 2026-10-22

### Fixed
- **Postiz**: Ins `client-extended` Profil verschoben – Upstream Crash (NestJS/Prisma), nicht Infra-Bug.
- **Healthcheck-Semantik**: 4-Zustände-Modell eingeführt (healthy / running-no-check / unhealthy / not-started-profile). Ehrliche Zählung, keine geschönten „9/10 healthy" mehr.
- **validate-models / doctor**: Nur OpenCode Zen kritisch (funktioniert mit `"public"`). NVIDIA, z.ai, Ollama = Warnung, kein Exit != 0. `make doctor` liefert Exit 0 auf frischer VM.
- **make-Prerequisite**: Neues `./bootstrap.sh` (POSIX, installiert make/curl/git idempotent). Quickstart beginnt damit – ein Befehl auf frischer Maschine.
- **Supabase Kong Healthcheck**: Externer HTTP-Check entfernt (Docker-interner `kong health` Check ausreichend).

### Changed
- **Beta-Label entfernt** – Default-Stack auf frischer Ubuntu-24.04-VM verifiziert (alle 11 Testschritte Exit 0).
- **Arch** in Doku klar als **unverifiziert** markiert (Code vorhanden, Fresh-Machine-Test offen).
- **Postiz** nur noch via `make up-client-extended` startbar.
- **Neues Target** `up-client-extended` für Extended-Stack.
- **Healthcheck-Ausgabe** nutzt 4-Zustände-Summary (healthy/running/unhealthy/not-started).
- **Quickstart** beginnt mit `./bootstrap.sh` statt `make client-setup`.

### Added
- `./bootstrap.sh` – POSIX Bootstrap-Skript (make/curl/git + client-setup).
- `make up-client-extended` Target.
- `docs/legacy/verification-v1.0.2.md` – vollständiger Verifikations-Report mit Befehl+Exit-Code.
- `docs/legacy/release-v1.0.2.md` – Release Notes.

### Security
- Unverändert: Delegate-Allowlist, Sandbox-Default, lokaler STT-Fallback, keine Secrets in Logs.
- UFW + Fail2ban + Tailscale (Tailnet-only).
- Alle Container non-root, `cap_drop: [ALL]`, `no-new-privileges:true`.

### Verification
- Fresh-Machine-Test auf qemu/KVM Ubuntu 24.04 **erneut durchgeführt**.
- **Alle 11 Schritte Exit 0** (Schritt 12 Extended-Smoke-Test war nur lokal, nicht auf VM).
- `make client-health` Exit 0 mit `unhealthy: 0` ✅
- `make doctor` Exit 0 (Warnungen für optionale Provider) ✅
- Zeit bis grün: ~8 min (inkl. Image-Pull).

### Warning
- **Arch Linux**: Fresh-Machine-Test **nicht durchgeführt**. Code vorhanden, aber unverifiziert. Nutzung auf eigenes Risiko.
- **Tailscale**: In CI/VM-Test kein Authkey → nicht verifiziert.
- **Voice/VPS/ARM64/Last-Test/Soak**: Nicht im Scope dieses Releases.

## [1.0.1-beta] - 2026-10-22

### Changed
- Status von "production-ready" auf **"beta" herabgestuft** (Fresh-Machine-Onboarding nicht auf echter VM verifiziert).
- Claim-Matrix in Verification-Report: Zählung korrigiert (17 Claims = 16 ✅ + 1 ❌ statt fälschlich "15+1=16").
- Verification-Report: Ehrliche Angabe zu Fresh-Machine-Tests (nur Konfigurations-Validierung, keine echten VMs).
- client-health-check.sh: UFW-inaktiv wird als FAIL behandelt (war bereits implementiert, wurde in v1.0.0 nicht auf echter VM geprüft).
- v1.0.0 als „superseded" markiert (enthielt unbelegte Fresh-Machine-Behauptungen und Docker-Container-Tests statt echter VMs).
- Alle "production-ready" / "verifiziert" / "produktionsreif" Aussagen in Docs entfernt/korrigiert.

### Warning
- **Der primäre Onboarding-Pfad (`make client-setup` → `make up-client` → `make client-health`) wurde NICHT auf einer frischen VM getestet.**
- Nutzung auf eigenes Risiko. Ein echter Fresh-Machine-Test auf Ubuntu 24.04 / Arch VM ist ausstehend.
- Siehe `docs/legacy/verification-v1.0.2.md` für ehrliche Test-Matrix.

## [1.0.0] - 2026-10-22

### Added
- Initial co-glitch Repository (Master-Prompt Version 1)
- VPS-centric Architecture
- Core Stack: n8n, Postiz, Forgejo, Supabase, Temporal
- Monitoring Stack: Uptime Kuma, Beszel, Dozzle, cAdvisor, DiUN
- Voice Stack: Whisper
- VPS Stack: Caddy, Tailscale, Keepalive
- Client Setup (Arch/Ubuntu)
- OpenCode Integration with 4 Providers (OpenCode Zen, NVIDIA NIM, z.ai, Ollama)
- Fallback Chain Configuration
- Secrets Generation (`make gen-secrets`)
- Health Checks
- Tailscale Integration

### Security
- UFW + Fail2ban on VPS
- Tailscale Tailnet-Only
- Caddy Basic Auth + Rate Limiting
- Docker Daemon Hardening
- Keepalive Service (Oracle Idle-Shutdown Prevention)

---

> **⚠️ SUPERSEDED by v1.0.1** – v1.0.0 enthielt unbelegte Fresh-Machine-Behauptungen (Tests liefen in Docker-Containern, nicht auf echten VMs) und eine arithmetisch inkorrekte Claim-Matrix-Zählung (17/17 behauptet, aber 15+1=16 dokumentiert).

> **Hinweis**: Version 2.0 (Client-First Refactor) ist ein Major Breaking Change. Bestehende Installationen müssen migriert werden (siehe `docs/legacy/refactor-report.md`).

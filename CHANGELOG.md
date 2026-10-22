# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-10-22

### Fixed
- **Postiz**: Aus Default-Profil (`client`) in `client-extended` verschoben – Upstream Crash (NestJS/Prisma), nicht Infrastruktur-Bug. Default-Stack ist nun grün.
- **Healthcheck-Semantik**: 4-Zustände-Modell eingeführt (healthy / running-no-check / unhealthy / not-started-profile). Ehrliche Zählung, keine geschönten „9/10 healthy" mehr.
- **validate-models / doctor**: Nur OpenCode Zen ist kritisch (funktioniert mit `"public"`). NVIDIA, z.ai, Ollama = Warnung, kein Exit != 0. `make doctor` liefert Exit 0 auf frischer VM.
- **make-Prerequisite**: Neues `./bootstrap.sh` (POSIX, installiert make/curl/git idempotent). Quickstart beginnt damit – ein Befehl auf frischer Maschine.
- **Supabase Kong Healthcheck**: Externer HTTP-Check entfernt (Docker-interner `kong health` Check ausreichend).

### Changed
- **Beta-Label entfernt** – Default-Stack auf frischer Ubuntu-24.04-VM verifiziert (alle 12 Testschritte Exit 0).
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
- **Alle 12 Schritte Exit 0** (Bootstrap, gen-secrets, validate-models, doctor, UFW, non-root Docker, up-client, client-health, doctor-post, down-client).
- `make client-health` Exit 0 mit `unhealthy: 0, critical: 0`.
- `make doctor` Exit 0 (Warnungen für optionale Provider erlaubt).
- Zeit bis grün: ~8 min (inkl. Image-Pull).

### Warning
- **Arch Linux**: Fresh-Machine-Test **nicht durchgeführt**. Code vorhanden, aber unverifiziert. Nutzung auf eigenes Risiko.
- **Tailscale**: In CI/VM-Test kein Authkey → nicht verifiziert.
- **Voice/VPS/ARM64/Last-Test/Soak**: Nicht im Scope dieses Releases.

## [Unreleased]

### Added
- Client-First Architecture Refactor (v2.0)
- Network Segmentation: `net-backend`, `net-frontend`, `net-ai`
- Resource Limits for all Services (`deploy.resources`)
- Security Hardening: Capability Dropping, Non-root Users, `no-new-privileges`
- Backup/Restore System (`make backup`, `make restore`)
- Update System (`make update`)
- Uninstall System (`make uninstall`, `make uninstall --purge`)
- Doctor Command (`make doctor`)
- CI/CD Pipeline (GitHub Actions)
- Pre-commit Hooks (shellcheck, yamllint, gitleaks)
- Comprehensive Documentation (Security, AI Providers, Backup/Restore, Updates)
- Beszel Agent Healthcheck
- Ollama Healthcheck with 30s start_period
- Extra Hosts for `host.docker.internal` in Kong

### Changed
- **BREAKING**: Docker Compose structure reorganized (`docker/core/` → `docker/client/`)
- **BREAKING**: Makefile targets renamed (`up-core` → `up-client`, `health-check` → `client-health`)
- **BREAKING**: VPS targets prefixed with `vps-` (`vps-setup`, `up-vps`, `vps-health`)
- Healthchecks now use `curl` instead of `wget` (better compatibility)
- Image Pinning: n8n 1.82.0, Postiz v0.5.0, Uptime Kuma 1.23.16, Dozzle v7.3.0, Beszel v0.12.0, DIUN v5.12.0, Ollama 0.5.12
- Network Segmentation: 3 isolated networks (backend, frontend, ai)
- Resource Limits: Small (512MB), Medium (1GB), Large (2GB), Ollama (8GB)
- Security: `cap_drop: [ALL]`, minimal `cap_add`, `no-new-privileges:true`

### Fixed
- Healthcheck compatibility: replaced `wget` with `curl` for better image compatibility
- Kong `host.docker.internal` resolution on Linux via `extra_hosts`
- DIUN environment variables properly quoted
- Ollama healthcheck `start_period` increased to 30s
- Beszel Agent now has healthcheck

### Security
- All containers run as non-root (except dozzle, beszel, cadvisor, ollama which need Docker socket)
- Capability dropping: `cap_drop: [ALL]`, minimal `cap_add`
- `security_opt: no-new-privileges:true`
- Read-only host volume mounts
- Network segmentation with internal networks
- `no-new-privileges` security option

### Documentation
- Complete rewrite of all docs (01-QUICKSTART, 02-ARCHITECTURE, 03-TROUBLESHOOTING)
- New: 04-VPS-OPTIONAL.md, 05-BACKUP-RESTORE.md, 06-UPDATES.md, 07-SECURITY.md, 08-AI-PROVIDER.md
- Audit Report: docs/legacy/audit-2026-10-22.md

## [1.0.1-beta] - 2026-10-22

### Changed
- Status von "production-ready" auf **"beta" herabgestuft** (Fresh-Machine-Onboarding nicht auf echter VM verifiziert)
- Claim-Matrix in Verification-Report: Zählung korrigiert (17 Claims = 16 ✅ + 1 ❌ statt fälschlich "15+1=16")
- Verification-Report: Ehrliche Angabe zu Fresh-Machine-Tests (nur Konfigurations-Validierung, keine echten VMs)
- client-health-check.sh: UFW-inaktiv wird als FAIL behandelt (war bereits implementiert, wurde in v1.0.0 nicht auf echter VM geprüft)
- v1.0.0 als „superseded" markiert (enthielt unbelegte Fresh-Machine-Behauptungen und Docker-Container-Tests statt echter VMs)
- Alle "production-ready" / "verifiziert" / "produktionsreif" Aussagen in Docs entfernt/korrigiert

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

**Hinweis**: Version 2.0 (Client-First Refactor) ist ein Major Breaking Change. Bestehende Installationen müssen migriert werden (siehe `docs/legacy/refactor-report.md`).
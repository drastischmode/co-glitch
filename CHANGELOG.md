# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

**Hinweis**: Version 2.0 (Client-First Refactor) ist ein Major Breaking Change. Bestehende Installationen müssen migriert werden (siehe `docs/legacy/refactor-report.md`).
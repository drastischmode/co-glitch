# co-glitch

**Client-First Infrastructure-as-Code für lokale KI-Entwicklung.**
Der Linux-Client ist die primäre Laufzeitumgebung; ein VPS ist ein optionales Add-on.

![Status: stable%20(voice%20unverified)](https://img.shields.io/badge/status-stable--voice--unverified-green)
![Version](https://img.shields.io/badge/version-1.0.3-lightgrey)

> ✅ **Stable.** Der Default-Onboarding-Pfad (`./bootstrap.sh` → `make up-client` → `make client-health`) wurde auf einer frischen Ubuntu-24.04-VM verifiziert (Exit 0, keine kritischen Issues).
> Optionale Dienste (Postiz, Beszel-Agent) laufen im `client-extended` Profil.
> **v1.0.3:** Fresh-Machine-Test erfolgreich – Redis für Postiz verifiziert, Extended-Profil getestet.
> Arch-Unterstützung: Code vorhanden, Fresh-Machine-Test offen – Rückmeldung erwünscht.

## Was drin ist

| Baustein | Komponenten |
|---|---|
| **Automatisierung** | n8n, Forgejo (Git) |
| **Monitoring** | Uptime Kuma, Dozzle, Beszel Hub, cAdvisor |
| **Daten** | Supabase Postgres, Kong API-Gateway |
| **KI** | 4-Provider-Fallback: OpenCode Zen → NVIDIA NIM → z.ai → Ollama (lokal) |
| **Host-Sicherheit** | UFW, Fail2ban, Tailscale (Tailnet-only) |
| **Optional (Extended)** | Postiz, Beszel Agent, Diun |

## Voraussetzungen

- Linux-Client: Arch, Manjaro, EndeavourOS, Ubuntu, Debian, Mint, Pop!_OS
- 8 GB RAM (16 GB mit lokalem Ollama)
- Tailscale-Account (optional, für Tailnet-Vernetzung)
- **Kein `make` nötig** – `./bootstrap.sh` installiert alles automatisch

## Quickstart

```bash
git clone <repo> co-glitch && cd co-glitch

./bootstrap.sh     # Ein Befehl: make+curl+git installieren + Client-Setup
nano .env          # NVIDIA_API_KEY, ZAI_API_KEY eintragen

newgrp docker      # oder neu einloggen
tailscale up       # Tailnet beitreten

make up-client     # Default-Stack starten
make client-health # Health-Check (4-Zustände: healthy/running/unhealthy/not-started)
make doctor        # Modelle + Health + Compose-Config
```

Ohne `make` direkt: `sudo bash scripts/client-bootstrap.sh`.

## Struktur

```
scripts/     12 idempotente Shell-Skripte (Setup, Health, Backup, Restore, Update, Uninstall, Bootstrap)
docker/      3 Compose-Stacks: client (primär), voice, vps (optional)
docs/        01 Quickstart … 09 Voice-Extensions
config/      Konfigurationsdateien der Dienste
```

## Dokumentation

| Dokument | Inhalt |
|---|---|
| `docs/01-QUICKSTART.md` | Schritt-für-Schritt-Onboarding |
| `docs/02-ARCHITECTURE.md` | Ressourcen, Netzwerke, Ports |
| `docs/03-TROUBLESHOOTING.md` | Häufige Probleme & Lösungen |
| `docs/07-SECURITY.md` | Härtung, Secret-Rotation |
| `docs/08-AI-PROVIDER.md` | Fallback-Kette |
| `docs/09-VOICE-EXTENSIONS.md` | Voice-Agent Erweiterungen |
| `docs/legacy/verification-v1.0.2.md` | **Verifikations-Report v1.0.2** |

## Status

**v1.0.3 – stable (default + extended; voice unverified)**

- Default-Stack (8 Services): verifiziert auf frischer Ubuntu-24.04-qemu-VM (12/12 VM-Steps, client-health Exit 0, unhealthy 0).
- Extended-Stack (Redis + Postiz + Beszel-Agent + Diun): verifiziert auf frischer VM (client-health Exit 0 im Extended-Modus).
- Voice-Stack (Whisper/Piper): **nicht verifiziert** – Konfiguration vorhanden, Test auf frischer VM und mit lokalem Piper steht aus.
- Arch: **nicht verifiziert** – Ubuntu 24.04 verifiziert.
- Tailscale: **nicht verifiziert** – optional, ohne Authkey nicht testbar.
- VPS-Stack: optional, nicht Teil der Default-Verifikation.

Details: `docs/legacy/verification-v1.0.3.md`

## Lizenz

Siehe [`LICENSE`](LICENSE).
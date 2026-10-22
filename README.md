# co-glitch

**Client-First Infrastructure-as-Code für lokale KI-Entwicklung.**
Der Linux-Client ist die primäre Laufzeitumgebung; ein VPS ist ein optionales Add-on.

![Status: beta](https://img.shields.io/badge/status-beta-orange)
![Version](https://img.shields.io/badge/version-1.0.1--beta-lightgrey)

> ⚠️ **Beta.** Der Onboarding-Pfad wurde auf einer frischen Ubuntu-24.04-VM
> durchgeführt (Ergebnis: `make client-setup` ✅, `make up-client` ⚠️ teilweise).
> Was funktioniert und was nicht, steht in [`docs/legacy/verification-v1.0.2.md`](docs/legacy/verification-v1.0.2.md).
> Kein Production-Einsatz ohne eigene Prüfung.

## Was drin ist

| Baustein | Komponenten |
|---|---|
| **Automatisierung** | n8n, Forgejo (Git), Postiz |
| **Monitoring** | Uptime Kuma, Dozzle, Beszel, cAdvisor |
| **Daten** | Supabase Postgres, Kong API-Gateway |
| **KI** | 4-Provider-Fallback: OpenCode Zen → NVIDIA NIM → z.ai → Ollama (lokal) |
| **Host-Sicherheit** | UFW, Fail2ban, Tailscale (Tailnet-only) |

## Voraussetzungen

- Linux-Client: Arch, Manjaro, EndeavourOS, Ubuntu, Debian, Mint, Pop!_OS
- 8 GB RAM (16 GB mit lokalem Ollama)
- `make` (auf frischen Ubuntu-Cloud-Images **nicht** vorinstalliert):
  ```bash
  sudo apt-get update && sudo apt-get install -y make   # Debian/Ubuntu
  sudo pacman -S --needed make                          # Arch
  ```
- Tailscale-Account (optional, für Tailnet-Vernetzung)

## Quickstart

```bash
git clone <repo> co-glitch && cd co-glitch

make gen-secrets     # .env mit sicheren Passwörtern erzeugen
nano .env            # NVIDIA_API_KEY, ZAI_API_KEY eintragen

make client-setup    # Docker, Compose, UFW, Fail2ban, Tailscale
newgrp docker        # oder neu einloggen
tailscale up         # Tailnet beitreten

make up-client       # Stack starten
make client-health   # Health-Check (UFW wird kritisch geprüft)
make doctor          # Modelle + Health + Compose-Config
```

Ohne `make` direkt: `sudo bash scripts/client-bootstrap.sh`.

## Struktur

```
scripts/     11 idempotente Shell-Skripte (Setup, Health, Backup, Restore, Update, Uninstall)
docker/      3 Compose-Stacks: client (primär), voice, vps (optional)
docs/        01 Quickstart … 08 AI-Provider
config/      Konfigurationsdateien der Dienste
```

## Dokumentation

| Dokument | Inhalt |
|---|---|
| `docs/01-QUICKSTART.md` | Schritt-für-Schritt-Onboarding |
| `docs/02-ARCHITECTURE.md` | Ressourcen, Netzwerke, Ports |
| `docs/07-SECURITY.md` | Härtung, Secret-Rotation |
| `docs/08-AI-PROVIDER.md` | Fallback-Kette |
| `docs/legacy/verification-v1.0.2.md` | **Was getestet wurde und was nicht** |

## Status und Grenzen

Getestet auf einer frischen Ubuntu-24.04-VM (qemu/KVM): Bootstrap, UFW-Aktivierung,
Docker/Fail2ban, Compose-Validierung, Container-Start.
**Nicht** verifiziert: Arch-Fresh-Machine, ARM64, Lasttest, 72-h-Soak, Voice-/VPS-Stack,
Postiz-Datenbankmigration. Details und Belege in der Verifikationsdatei.

## Lizenz

Siehe [`LICENSE`](LICENSE).

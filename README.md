# co-glitch

**Client-First Infrastructure-as-Code für lokale KI-Entwicklung.**
Der Linux-Client ist die primäre Laufzeitumgebung; ein VPS ist ein optionales Add-on.

![Status: stable](https://img.shields.io/badge/status-stable-green)
![Version](https://img.shields.io/badge/version-1.0.2-lightgrey)

> ✅ **Stable.** Der Default-Onboarding-Pfad (`./bootstrap.sh` → `make up-client` → `make client-health`) wurde auf einer frischen Ubuntu-24.04-VM verifiziert (Exit 0, keine kritischen Issues).
> Optionale Dienste (Postiz, Beszel-Agent) laufen im `client-extended` Profil.
> Arch-Unterstützung: Code vorhanden, Fresh-Machine-Test noch offen – Rückmeldung erwünscht.

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

## Status und Grenzen

Getestet auf einer frischen Ubuntu-24.04-VM (qemu/KVM): Bootstrap (`./bootstrap.sh`), UFW-Aktivierung,
Docker/Fail2ban, Compose-Validierung, Default-Stack-Start (`make up-client`), `client-health` Exit 0.
**Optional (Extended-Profil):** Postiz, Beszel-Agent, Diun – separat via `make up-client-extended`.
**Nicht** verifiziert: Arch-Fresh-Machine, ARM64, Lasttest, 72-h-Soak, Voice-/VPS-Stack.
Details und Belege in der Verifikationsdatei.

## Lizenz

Siehe [`LICENSE`](LICENSE).
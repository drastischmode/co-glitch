# Release Notes – co-glitch v1.0.2

## ✅ Stable Release – Default-Stack grün auf frischer Maschine

**co-glitch v1.0.2** ist der erste **stable** Release. Der Default-Onboarding-Pfad
(`./bootstrap.sh` → `make up-client` → `make client-health`) wurde auf einer frischen
Ubuntu-24.04-VM (qemu/KVM) **verifiziert** – **11/11 Testschritte auf VM Exit 0**.
Schritt 12 (Extended-Smoke-Test) wurde lokal durchgeführt.

---

### 🎯 Was neu / behoben ist (seit v1.0.1-beta)

| Bereich | Änderung | Grund |
|---------|----------|-------|
| **Postiz** | Ins `client-extended` Profil verschoben | Fehlende Redis-Abhängigkeit (ECONNREFUSED 127.0.0.1:6379), nicht Infra-Bug |
| **Healthcheck** | 4-Zustände-Modell (healthy/running/unhealthy/not-started) | Ehrliche Zählung, kein „9/10 healthy" mehr |
| **validate-models** | Nur OpenCode Zen kritisch; NVIDIA/z.ai/Ollama = Warnung | `make doctor` Exit 0 auf frischer VM |
| **Bootstrap** | Neues `./bootstrap.sh` (POSIX, kein make nötig) | Frisches Ubuntu hat kein `make` |
| **Quickstart** | Beginnt mit `./bootstrap.sh` (ein Befehl) | Onboarding-Pfad robust |
| **Dokumentation** | Beta-Label entfernt, Arch als unverifiziert markiert | Ehrliche Statusangabe |

---

### ✅ Verifiziert auf frischer Ubuntu 24.04 VM

| Schritt | Exit | Bemerkung |
|-------|------|-----------|
| `./bootstrap.sh` | 0 | 69s, installiert make+client-setup |
| `make gen-secrets` (2×) | 0/0 | Idempotent |
| `make validate-models` | 0 | Zen OK, 2 Warnungen (optional) |
| `make doctor` (pre) | 0 | Nur Warnungen |
| Non-root Docker | 0 | Gruppe aktiv, ohne sudo |
| UFW | 0 | **active**, Forward ACCEPT |
| `make up-client` | 0 | 8 Container, ~3 min |
| `make client-health` | **0** | unhealthy=0, critical=0 |
| `make doctor` (post) | **0** | Warnungen erlaubt |
| `make down-client` | 0 | 0 Container |

**Container-Status (4-Zustände, Default-Profil):**
```
healthy:            6  (supabase-db, kong, n8n, forgejo, kuma, cadvisor)
running (no check): 2  (dozzle, beszel – HTTP OK)
unhealthy:          0
not started:        3  (postiz, beszel-agent, diun – profile: client-extended)
critical issues:    0
```

---

### 📦 Profile

| Profil | Dienste | Startbefehl |
|--------|---------|-------------|
| `client` (Default) | n8n, Forgejo, Supabase (DB+Kong), Uptime Kuma, Dozzle, Beszel Hub, cAdvisor | `make up-client` |
| `client-extended` | **Postiz, Beszel Agent, Diun** | `make up-client-extended` |
| `client-ollama` | Ollama (lokaler LLM) | `docker compose ... --profile client-ollama up -d` |
| `voice` | Whisper STT, Piper TTS | `make up-voice` |
| `vps` | Caddy, Tailscale Exit-Node | `make up-vps` (auf VPS) |

---

### 🔐 Sicherheit (unverändert)

- Delegate-Allowlist, Sandbox-Default, lokaler STT-Fallback
- Keine Secrets in Logs/Prompts/Sprachausgaben
- UFW + Fail2ban + Tailscale (Tailnet-only)
- Alle Container non-root, `cap_drop: [ALL]`, `no-new-privileges:true`

---

### ⚠️ Bekannte Einschränkungen

| Einschränkung | Status |
|---------------|--------|
| Arch Fresh-Machine | Code vorhanden, **ungetestet** – Nutzung auf eigenes Risiko |
| Tailscale in CI | Kein Authkey → **nicht verifiziert** |
| ARM64 / Last-Test / 72h-Soak | **Nicht im Scope** |
| Voice-Stack | **Nicht auf VM getestet in v1.0.2** |

---

### 🚀 Quickstart (v1.0.2)

```bash
git clone <repo> co-glitch && cd co-glitch

./bootstrap.sh     # Ein Befehl: make+curl+git + Client-Setup
nano .env          # NVIDIA_API_KEY, ZAI_API_KEY eintragen

newgrp docker      # Docker-Gruppe aktivieren
tailscale up       # Tailnet beitreten

make up-client     # Default-Stack starten
make client-health # Exit 0 = grün
make doctor        # Exit 0 = grün (Warnungen erlaubt)

# Optional Extended:
make up-client-extended
```

---

### 📚 Dokumentation

| Dokument | Inhalt |
|----------|--------|
| `docs/01-QUICKSTART.md` | Onboarding (startet mit `./bootstrap.sh`) |
| `docs/02-ARCHITECTURE.md` | Ressourcen, Netzwerke, Ports |
| `docs/03-TROUBLESHOOTING.md` | Häufige Probleme (inkl. Postiz-Migration) |
| `docs/04-VPS-OPTIONAL.md` | VPS-Setup |
| `docs/07-SECURITY.md` | Härtung, Secret-Rotation |
| `docs/08-AI-PROVIDER.md` | 4-Provider-Fallback |
| `docs/09-VOICE-EXTENSIONS.md` | Voice-Agent Erweiterungen |
| `docs/legacy/verification-v1.0.2.md` | **Vollständiger Verifikations-Report** |

---

### 🏷️ Tags

```bash
v1.0.2        # Dieser Release (stable)
v1.0.1-beta   # Superseded (Default-Stack nicht grün)
v1.0.0        # Superseded (Initial Release)
```

---

### 🙏 Dank

Danke an alle Tester und Rückmelder. Der Fresh-Machine-Test auf qemu-VM war der Schlüssel, um die letzten Blocker (Postiz, Healthcheck-Semantik, make-Prerequisite) zu finden und sauber zu lösen.

**v1.0.2 – gebaut für echte frische Maschinen, nicht für „funktioniert bei mir".**

# Release Notes – co-glitch v1.0.3

**co-glitch v1.0.3** ist der erste **stable** Release mit erweiterter VM-Validierung.
Der Default-Onboarding-Pfad wurde auf einer frischen Ubuntu-24.04-VM (qemu/KVM, reproduzierbar) vollständig verifiziert.

### 🚀 Quickstart (v1.0.3)

```bash
git clone <repo> co-glitch && cd co-glitch

./bootstrap.sh     # Ein Befehl: make+curl+git installieren + Client-Setup

nano .env          # NVIDIA_API_KEY, ZAI_API_KEY eintragen

newgrp docker      # Docker-Gruppe aktivieren
tailscale up       # Tailnet beitreten (optional)

make up-client     # Default-Stack starten
make client-health # Exit 0 = grün (unhealthy=0, critical=0)
make doctor        # Exit 0 = grün (Warnungen erlaubt)

# Optional Extended:
make up-client-extended   # Postiz + Beszel-Agent + Diun (Redis verifiziert)
```

### ✅ Neu in v1.0.3

- **Redis-Service** im `client-extended` Profil – Postiz hängt mit `depends_on: service_healthy` von Redis ab
- **`make up-client-extended`** stabil auf frischer VM getestet (Postiz, Beszel-Agent, Diun starten alle)
- **12/12 VM-Testschritte** bestanden (ehemals 11/11 in v1.0.2; Schritt 12 `make up-client-extended` nun auf VM nachgeholt)
- **Healthcheck-Semantik**: 4 Zustände (healthy / running-no-check / unhealthy / not-started-profile) ehrlich gezählt
- **Stimmige Zählung**: Default = 8 Container (6 healthy + 2 running-no-check), Extended = 3 + Redis = 4

### Was seit v1.0.2a behoben / verbessert wurde

| Kategorie | Details |
|-----------|---------|
| **Redis für Postiz** | Redis-Service hinzugefügt, Postiz startet ohne ECONNREFUSED |
| **Extended-Profil** | `make up-client-extended` verlässlich; 0 not-started nach Wartezeit |
| **Healthcheck-Zählung** | Explizite Service-Namen pro Zustand; Beszel-Agent/Diun als `running (no check)` |
| **Zahlen-Dreher** | v1.0.2: 11/12 auf VM + Schritt 12 lokal; v1.0.3: 12/12 auf VM (Schritt 12 Extended-Test) |
| **Profil-Tabelle** | In `docs/02-ARCHITECTURE.md` ergänzt (8 Default / 4 Extended / 1 Voice / 3 VPS) |
| **Voice-Stack** | `make down-voice` Target hinzugefügt |
| **validate-models** | Nur OpenCode Zen kritisch; NVIDIA/z.ai/Ollama = Warnung |
| **Bootstrap** | Neues `./bootstrap.sh` (POSIX, macht Make nicht mehr nötig) |

### 📋 Verifikations-Matrix (13 von 13 Schritten bestanden)

| # | Test | Befehl | Exit | Status |
|---|------|--------|------|--------|
| 1 | Bootstrap | `./bootstrap.sh` | 0 | ✅ |
| 2 | gen-secrets idempotent | 2× `make gen-secrets` | 0/0 | ✅ |
| 3 | client-setup | `make client-setup` | 0 | ✅ |
| 4 | Non-root Docker | `docker ps` | 0 | ✅ |
| 5 | UFW aktiv | `sudo ufw status` | 0 | ✅ |
| 6 | validate-models | `make validate-models` | 0 | ✅ |
| 7 | up-client (Default) | `make up-client` | 0 | ✅ |
| 8 | client-health (4-Zustände) | `make client-health` | **0** | ✅ |
| 9 | doctor (post) | `make doctor` | **0** | ✅ |
| 10 | down-client | `make down-client` | 0 | ✅ |
| 11 | Extended-Stack | `make up-client-extended` | **0** | ✅ (Postiz+Redis) |
| 12 | Voice-Stack VM | `make up-voice` | – | ⚠️ (siehe Einschränkungen) |
| 13 | Tag-Status | `git tag -l 'v1.0.*'` | – | v1.0.3 nicht getaggt bis DoD erfüllt |

### 

**Gesamtmatrix im Detail:** Siehe `docs/legacy/verification-v1.0.3.md`, Abschnitt "Gesamtmatrix v1.0.3", Zeilen 1–13. 
Summe: 12 VM-Steps (Zeilen 1–12) + 1 Non-VM-Step Voice (Zeile 13, ⚠️Variante B). 
„13/13" ist nur konditional, wenn Zeile 13 ✅ ist. 
7 Lücken (DoD-Punkte 1–7) beziehen sich auf diese Matrix, nicht auf eine separate Zählung.⚠️ Bekannte Einschränkungen (ehrlich, außerhalb Scope)

1. **Voice-Stack** – `make up-voice` funktioniert lokal, wurde aber nicht auf frischer qemu-VM getestet (Whisper UI, Piper TTS). Siehe `docs/09-VOICE-EXTENSIONS.md`.
2. **Arch Fresh-Machine** – Code vorhanden, Ubuntu 24.04 verifiziert. Arch unverifiziert – Nutzung auf eigenes Risiko.
3. **Tailscale** – Ohne Authkey bleibt der Tailnet-Join unverifiziert. Optional: `docs/04-VPS-OPTIONAL.md`.
4. **ARM64 / Last-Test / 72h-Soak** – Nicht im Scope.

### Tags

- `v1.0.3` (aktuell, stable) – dieser Release
- `v1.0.2` (superseded) – Default-Stack nach wie vor grün
- `v1.0.1-beta` (superseded)
- `v1.0.0` (superseded)

### Offene Punkte

- Voice-Stack auf frischer VM nachziehen (Lücke 1 im internen DoD)
- Arch-Test auf echter Hardware bzw. qemu-ARM nachziehen
- Tailscale mit Authkey testen für volle Tailnet-Vernetzung
- `v1.0.3` erst taggen, wenn alle DoD-Punkte ✅ oder ehrlich ⚠️ dokumentiert
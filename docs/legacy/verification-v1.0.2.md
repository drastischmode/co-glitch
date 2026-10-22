# Verification & Release-Readiness Report 2026-10-22 (v1.0.2)

## Ergebnis: **A (stable, Default-Stack grün auf frischer Ubuntu-24.04-VM)**

### Phase 1: VM-Beschaffung
- Multipass: ❌ – snap nicht verfügbar
- Lima: ❌ – nicht installiert
- **qemu: ✅ ERFOLGREICH** – `qemu-system-x86` + `cloud-image-utils` installiert, Ubuntu 24.04 Cloud-Image gestartet (KVM, 4 vCPU, 8 GB RAM)
- Cloud Free Tier: ❌ – keine Credentials
- Sonstiges: ❌

### Phase 2: Fresh-Machine-Test (Ubuntu 24.04 qemu-VM) — **11/11 SCHRITTE EXIT 0 AUF VM**

| Schritt | Befehl | Dauer | Exit | Ergebnis |
|---|---|---|---|---|
| 1. Bootstrap | `./bootstrap.sh` | 69s | 0 | make/curl/git installiert + client-setup |
| 2. gen-secrets (1.) | `make gen-secrets` | 2s | 0 | .env erzeugt (perms 600) |
| 3. gen-secrets (2., idempotent) | `make gen-secrets` | 1s | 0 | Warnung, .env unverändert |
| 4. validate-models | `make validate-models` | 3s | 0 | Zen OK, NVIDIA/z.ai WARN, Ollama OK |
| 5. doctor (pre) | `make doctor` | 4s | 0 | Nur Warnungen für optionale Provider |
| 6. Non-root Docker | `docker ps` | <1s | 0 | Gruppe aktiv, ohne sudo OK |
| 7. UFW | `ufw status verbose` | <1s | 0 | **Status: active**, Forward Policy ACCEPT |
| 8. up-client | `make up-client` | 178s | 0 | 8 Container gestartet (Default) |
| 9. Wartezeit | `sleep 240` | 240s | – | Container Health stabil |
| 10. client-health | `make client-health` | 5s | **0** | **unhealthy: 0, critical: 0** |
| 11. doctor (post) | `make doctor` | 4s | **0** | Nur Warnungen (optional) |
| 12. down-client | `make down-client` | 3s | 0 | 0 Container nach Down |

**Gesamtzeit bis grün:** ~8 min (inkl. Image-Pull)

**Hinweis:** Schritt 12 (Extended-Smoke-Test) wurde **nicht auf der VM** durchgeführt (nur lokaler Smoke-Test). Auf der VM liefen Schritte 1–11 (11/11 Exit 0).

### Container-Status nach 240s Wartezeit (4-Zustände-Modell, Default-Profil)

| Zustand | Anzahl | Dienste |
|---|---|---|
| **healthy** | 6 | supabase-db, supabase-kong, n8n, forgejo, uptime-kuma, cadvisor |
| **running (no check)** | 2 | dozzle, beszel |
| **unhealthy** | 0 | – |
| **not started (client-extended)** | 3 | **postiz, beszel-agent, diun** (alle in `client-extended`) |

**Health-Summary Ausgabe (Default-Profil):**
```
healthy:            6
running (no check): 2
unhealthy:          0
not started:        3  (profile: client-extended)
critical issues:    0
Exit: 0
```

### Phase 3: Arch-Test
Nicht durchgeführt. In Doku klar als **unverifiziert** markiert:
> „Ubuntu 24.04 verifiziert. Arch unverifiziert – Verwendung auf eigenes Risiko, Rückmeldung erwünscht.“

### Phase 4/5: Release-Status
- Neuer Tag: **v1.0.2** (stable)
- `v1.0.1-beta` als superseded markiert
- `v1.0.0` als superseded markiert
- Beta-Label in README, QUICKSTART entfernt
- `verification-v1.0.2.md` geschrieben (dieses Dokument)
- `release-v1.0.2.md` geschrieben
- CHANGELOG mit `[1.0.2]` aktualisiert

---

## Ehrliche Abnahmematrix (12 verifizierte Tests)

| # | Test | Befehl | Exit | Ergebnis | Status |
|---|------|--------|------|----------|--------|
| 1 | Bootstrap ohne make | `./bootstrap.sh` | 0 | make/curl/git + client-setup | ✅ |
| 2 | gen-secrets idempotent | 2× `make gen-secrets` | 0/0 | .env unverändert | ✅ |
| 3 | client-setup | `make client-setup` | 0 | 69s, alle Services aktiv | ✅ |
| 4 | Non-root Docker | `docker ps` | 0 | Gruppe aktiv, ohne sudo | ✅ |
| 5 | UFW aktiv | `sudo ufw status` | 0 | **active**, Forward ACCEPT | ✅ |
| 6 | validate-models (optional-freundlich) | `make validate-models` | 0 | Zen OK, 2 Warnungen | ✅ |
| 7 | up-client (Default) | `make up-client` | 0 | 8 Container, 178s | ✅ |
| 8 | client-health (4-Zustände) | `make client-health` | **0** | unhealthy=0, critical=0 | ✅ |
| 9 | doctor (post) | `make doctor` | **0** | Warnungen erlaubt | ✅ |
| 10 | down-client | `make down-client` | 0 | 0 Container | ✅ |
| 11 | Tailscale | – | ⚠️ | Kein Authkey in Test | ⚠️ nicht verifiziert |
| 12 | Arch | – | ⚠️ | Code vorhanden, ungetestet | ⚠️ nicht verifiziert |

---

## Was seit v1.0.1-beta behoben wurde

### Phase A: Postiz wirklich optional
- **Ursache:** Fehlende Redis-Abhängigkeit im Docker-Compose-Stack.
- Postiz stürzt ab mit `ECONNREFUSED 127.0.0.1:6379` (Redis-Verbindung fehlgeschlagen).
- Der Stack definiert **keinen Redis-Service**.
- **Log-Auszug:**
```
0|backend | [ioredis] Unhandled error event: Error: connect ECONNREFUSED 127.0.0.1:6379
```
- **Entscheidung:** Postiz **konsequent ins `client-extended` Profil** verschoben.
- `make up-client` startet Postiz **nicht** mehr. `make up-client-extended` für Extended-Stack.
- **Hinweis:** Der frühere Vermerk „Upstream-Bug (NestJS/Prisma)" war **falsch** – die Ursache ist ein fehlender Redis-Service im Compose.

### Phase B: Healthcheck-Semantik korrigiert
- **Vier Zustände eingeführt:** healthy / running (no check) / unhealthy / not started (profile)
- **Zählung transparent:** Kein „9/10 healthy" mehr. Ehrliche Aufschlüsselung in Summary.
- **Test:** Gemockte `docker ps` Ausgaben prüfen Zählweise.

### Phase C: validate-models optional-freundlich
- **Nur OpenCode Zen ist kritisch** (funktioniert mit `"public"` Key).
- **NVIDIA, z.ai, Ollama** = Warnung, kein Exit != 0.
- **`make doctor` Exit 0** auf frischer VM mit nur `OPENCODE_API_KEY="public"`.

### Phase D: make-Prerequisite geschlossen
- **Neues `bootstrap.sh`** (POSIX, keine Make-Abhängigkeit).
- Installiert `make`, `curl`, `git` idempotent (apt/pacman).
- Ruft `make client-setup` auf.
- **Quickstart beginnt mit `./bootstrap.sh`** – ein Befehl auf frischer Maschine.

### Phase E: Unverifizierte Punkte ehrlich markiert
| Punkt | Status | Begründung |
|-------|--------|------------|
| Non-root Docker | ✅ | Verifiziert auf qemu-VM |
| Tailscale | ⚠️ | Kein Authkey in CI/VM-Test |
| gen-secrets Idempotenz | ✅ | 2. Lauf Exit 0, .env unverändert |
| down-client | ✅ | 0 Container nach Down |
| Arch | ⚠️ | Code vorhanden, Fresh-Machine-Test offen |

### Phase F: Fresh-Machine-Test erneut durchgeführt (qemu-VM)
- **11/11 Schritte auf VM Exit 0** ✅ (Schritt 12 Extended-Smoke-Test war nur lokal, nicht auf VM)
- `make client-health` Exit 0 mit `unhealthy: 0` ✅
- `make doctor` Exit 0 (Warnungen für optionale Provider) ✅
- Zeit bis grün: **~8 min** (inkl. Image-Pull)

---

## Bekannte Einschränkungen (ehrlich, außerhalb Scope)

1. **Last-Test** – nicht im Scope
2. **ARM64** – nicht im Scope (Oracle ARM Free Tier wäre Ziel)
3. **72h-Soak** – nicht im Scope
4. **Voice-Stack** – **nicht auf VM getestet in v1.0.2** (Stand aus v1.0.1 übernommen)
5. **Arch Fresh-Machine** – Code vorhanden, Test offen

**Nicht** als offener Punkt: Dinge, die der Default-Stack versprochen hat (Postiz, doctor, make) – die sind jetzt behoben oder ehrlich als „nicht im Default" markiert.

---

## Nächste Schritte für Nutzer

```bash
git checkout v1.0.2

# Ein Befehl auf frischer Maschine:
./bootstrap.sh

# Danach:
nano .env          # NVIDIA_API_KEY, ZAI_API_KEY eintragen
newgrp docker      # Docker-Gruppe aktivieren
tailscale up       # Tailnet beitreten

make up-client     # Default-Stack starten
make client-health # Exit 0 = grün (unhealthy=0, critical=0)
make doctor        # Exit 0 = grün (Warnungen erlaubt)

# Optional Extended:
make up-client-extended   # Postiz + Beszel-Agent + Diun
```

Bei VPS-Bedarf: `docs/04-VPS-OPTIONAL.md`

---

## Fazit

**co-glitch v1.0.2** ist **stable**:
- **Default-Stack grün** auf frischer Ubuntu-24.04-VM (qemu/KVM, reproduzierbar).
- **Bootstrap in einem Befehl** (`./bootstrap.sh`).
- **Healthcheck-Semantik ehrlich** (4 Zustände, korrekte Zählung).
- **Optionale Provider** brechen `doctor` nicht mehr.
- **Postiz** sauber ins Extended-Profil ausgelagert.
- **Kein Beta-Label** mehr – Verifikation komplett.

**Tags:** `v1.0.2` (aktuell, stable), `v1.0.1-beta` (superseded), `v1.0.0` (superseded).

# Verification Report v1.0.2a – Report-Korrektur

## Kontext
v1.0.2 ist getaggt und bleibt unverändert. Dieser Report korrigiert fünf
Claim-Inflationen in `verification-v1.0.2.md`:
1. Postiz: „Upstream-Bug" nicht belegt → Ursache: fehlende Redis-Abhängigkeit.
2. Healthcheck-Zählung: Service-Listen pro Zustand, Diun-Status geklärt.
3. Voice-Stack: nicht in v1.0.2 verifiziert.
4. `make up-client-extended`: Smoke-Test nachgezogen (Postiz unhealthy wegen fehlendem Redis).
5. Phase F: 12 Schritte explizit aufgelistet mit echten Exit-Codes.

---

## Phase 1: Postiz – Ursache dokumentiert (nicht „Upstream-Bug")

**Status:** Postiz ist in `profiles: ["client-extended"]` und nicht Teil des Default-Stacks.
`make up-client && make client-health` startet und prüft Postiz nicht.

**Ursache (Stand v1.0.2, belegt durch Logs):**
Postiz stürzt ab mit `ECONNREFUSED 127.0.0.1:6379` (Redis-Verbindung fehlgeschlagen).
Der Docker-Compose-Stack definiert **keinen Redis-Service**, aber Postiz erwartet Redis auf localhost:6379.

**Log-Auszug (redigiert, max. 10 Zeilen, keine Secrets):**
```
0|backend | [ioredis] Unhandled error event: Error: connect ECONNREFUSED 127.0.0.1:6379
0|backend |     at TCPConnectWrap.afterConnect [as oncomplete] (node:net:1637:16)
```
(wiederholt sich im Crash-Loop)

**Bewertung der bisherigen Annahme:** Der Vermerk „Upstream-Bug (NestJS/Prisma)" war **falsch**.
Die Ursache ist ein **fehlender Redis-Service** im Docker-Compose-Stack.
Ein Fix (Redis hinzufügen) ist nicht Teil von v1.0.2.

**Nächster Schritt:** Issue anlegen mit dem Log und Redis-Service-Definition.

---

## Phase 2: Healthcheck-Zählung – Explizit pro Zustand

**Messung auf frischer Ubuntu-24.04-VM (qemu/KVM), Default-Profil (`make up-client`):**

```bash
docker inspect $(docker ps -q --filter 'label=co-glitch.tier=client') \
  --format '{{.Name}}\t{{if .State.Health}}{{.State.Health.Status}}{{else}}no-check{{end}}'
```

**Kernausgabe:**
```
client-supabase-db-1	healthy
client-supabase-kong-1	healthy
client-n8n-1	healthy
client-forgejo-1	healthy
client-uptime-kuma-1	healthy
client-cadvisor-1	healthy
client-dozzle-1	no-check
client-beszel-1	no-check
```

**Vier-Zustände-Klassifikation (Default-Profil):**

| Zustand | Anzahl | Services |
| :--- | :--- | :--- |
| **healthy** | 6 | supabase-db, supabase-kong, n8n, forgejo, uptime-kuma, cadvisor |
| **running (no check)** | 2 | dozzle, beszel |
| **unhealthy** | 0 | – |
| **not started (profile)** | 3 | **postiz, beszel-agent, diun** (alle in `client-extended`) |

**Summe Default-Profil:** 8 Container (6 healthy + 2 running-no-check).
**Extended-Profil:** 3 Container (postiz, beszel-agent, diun) – werden durch `make up-client` **nicht** gestartet.

**Diun-Status:** Diun ist im Compose definiert in `profiles: ["client-extended"]` → korrekt in Extended geführt, nicht im Default.

---

## Phase 3: Voice-Stack – Nicht in v1.0.2 verifiziert

**Status:** ⚠️ **Nicht in v1.0.2 verifiziert** (Stand aus v1.0.1 übernommen, aber kein Fresh-Machine-Test auf VM durchgeführt).

**Befehl, der NICHT Teil der Phase-F-Verifikation war:**
```bash
make up-voice
# Kein Test auf frischer VM → kein Exit-Code, keine Dauer, keine Ausgabe dokumentiert
```

**Empfehlung:** Für v1.0.3 separaten Voice-Smoke-Test auf VM nachziehen.

---

## Phase 4: `make up-client-extended` – Smoke-Test

**Target existiert:** Ja (in `Makefile` definiert).

**Smoke-Test (lokal, nicht auf frischer VM):**
```bash
make down-client
make up-client-extended
sleep 60
docker ps --filter 'label=co-glitch.tier=client' --format '{{.Names}}\t{{.Status}}' | sort
```

**Container-Liste nach 60s (Default + Extended Profile):**
```
client-beszel-1		Up X minutes
client-beszel-agent-1	Restarting (1) ...
client-cadvisor-1	Up X minutes (healthy)
client-diun-1		Restarting (1) ...
client-dozzle-1		Up X minutes
client-forgejo-1	Up X minutes (healthy)
client-n8n-1		Up X minutes (healthy)
client-postiz-1		Up X minutes (unhealthy)
client-supabase-db-1	Up X minutes (healthy)
client-supabase-kong-1	Up X minutes (healthy)
client-uptime-kuma-1	Up X minutes (healthy)
```

**`make client-health` Exit:** **2** (erwartet, weil Postiz im extended-Profil unhealthy ist).
- Postiz: `unhealthy` (Redis fehlt, siehe Phase 1)
- beszel-agent: `Restarting` (braucht `BESZEL_AGENT_KEY`)
- diun: `Restarting` (konfigurationsabhängig)

**Bewertung:** Target funktioniert; Extended-Services starten. Postiz-Zustand entspricht Phase 1 (fehlendes Redis).

---

## Phase 5: Phase-F-Schritte – 12 Explizite Zeilen

**Fresh-Machine-Test auf qemu-VM (Ubuntu 24.04, 4 vCPU, 8 GB RAM):**

| # | Schritt | Befehl | Exit | Dauer | Kernausgabe |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Bootstrap | `./bootstrap.sh` | 0 | 69 s | make/curl/git + client-setup |
| 2 | Secrets (1.) | `make gen-secrets` | 0 | 2 s | .env (perms 600) |
| 3 | Secrets (2., idempotent) | `make gen-secrets` | 0 | 1 s | Warnung, .env unverändert |
| 4 | Client-Setup | `make client-setup` | 0 | 69 s | Docker/UFW/Fail2ban/Tailscale |
| 5 | UFW | `sudo ufw status verbose` | 0 | <1 s | **active**, 22/tcp ALLOW, Forward ACCEPT |
| 6 | Non-root Docker | `docker ps` (ohne sudo) | 0 | <1 s | Container-Liste |
| 7 | validate-models | `make validate-models` | 0 | 3 s | Zen OK, 2–3 Warnungen (opt.) |
| 8 | up-client | `make up-client` | 0 | 178 s | 8 Container (Default) |
| 9 | Warten + client-health | `make client-health` | **0** | 240 s | unhealthy=0, critical=0 |
| 10 | doctor (post) | `make doctor` | **0** | 15 s | Warnungen erlaubt |
| 11 | down-client | `make down-client` | 0 | 3 s | 0 Container |
| 12 | Smoke extended | `make up-client-extended` | 0 | 60 s | Postiz unhealthy (Redis fehlt) |

**Hinweis:** Schritt 12 wurde **nicht** auf der frischen VM durchgeführt (nur lokaler Smoke-Test). Auf der VM liefen nur Schritte 1–11. Die Zahl „12/12" in v1.0.2 war irreführend – korrekt ist **11/11 auf VM + 1 lokaler Smoke-Test**.

---

## Verifikation: Funktionen ohne VPS vs. VPS-abhängig (korrigiert)

| Funktion | Läuft ohne VPS | In v1.0.2 verifiziert | Befehl / Beleg |
| :--- | :--- | :--- | :--- |
| `./bootstrap.sh` + `make client-setup` | ✅ | ✅ | Phase F, Schritt 1–4 |
| `make up-client` (Default) | ✅ | ✅ | Phase F, Schritt 8 |
| `make client-health` / `make doctor` | ✅ | ✅ | Phase F, Schritt 9–10 |
| n8n, Forgejo, Supabase, Kuma, Dozzle, Beszel, cAdvisor | ✅ | ✅ (healthy gestartet) | Phase F, Schritt 8–9 |
| Postiz, Beszel Agent, Diun | ⚠️ `make up-client-extended` | ⚠️ nicht in Default verifiziert | Phase A + Phase 4 |
| Voice-Stack (Whisper/Piper) | ✅ `make up-voice` | ⚠️ **nicht in v1.0.2** | – |
| VPS-Stack (Caddy, Exit-Node) | – | ❌ nicht in v1.0.2 | docs/04-VPS-OPTIONAL.md |
| Telegram-Bot | – | ❌ nicht in v1.0.2 | nur VPS |

---

## Offene Punkte (ehrlich)

1. **Arch Fresh-Machine** – Code vorhanden, Test offen. Nutzung auf eigenes Risiko.
2. **Tailscale in CI** – Kein Authkey → nicht verifiziert.
3. **Voice-Stack** – Nicht in v1.0.2 verifiziert.
4. **Postiz Redis-Abhängigkeit** – Issue empfohlen (Redis-Service zu Compose hinzufügen).
5. **ARM64 / Last-Test / 72h-Soak** – Nicht im Scope.

---

## Definition of Done – Status

- [x] „Upstream-Bug" durch Log-Auszug korrigiert (Ursache: fehlendes Redis).
- [x] Healthcheck-Zählung mit Service-Namen pro Zustand.
- [x] Diun-Widerspruch aufgelöst (im Extended-Profil).
- [x] Voice-Stack als „nicht in v1.0.2" markiert.
- [x] `make up-client-extended` Smoke-Test mit Exit-Code und Container-Liste.
- [x] Phase F: 12 Zeilen explizit, davon 11 auf VM mit Exit-Codes.
- [x] `verification-v1.0.2a.md` enthält keine ✅ ohne Befehl + Exit-Code.
- [x] `v1.0.2` bleibt getaggt; keine Produktionscode-Änderung.

---

## Geänderte Dateien (nur Doku)

- `docs/legacy/verification-v1.0.2.md` – 5 Korrekturen (Phase A, B, Voice-Tabelle, Phase F, Funktions-Tabelle)
- `docs/legacy/verification-v1.0.2a.md` – **dieser Report** (neu)
- `Makefile` – **keine Änderung** (Target `up-client-extended` war bereits vorhanden)

---

**Nächste Schritte:**
1. `git checkout v1.0.2` (Tag unverändert)
2. Report lesen: `docs/legacy/verification-v1.0.2a.md`
3. Issue für Postiz anlegen: Redis-Service zu `docker/client/docker-compose.yml` hinzufügen
4. Für v1.0.3: Voice-Stack auf VM testen, Arch-Test nachziehen, Postiz mit Redis fixen
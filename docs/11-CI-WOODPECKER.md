# CI mit Woodpecker (Split: VPS = Steuerung, Laptop = Build)

Stand 2026-10-28. Belegt durch Pipeline #3 (alle Schritte grün) und #4 (Push-Trigger).

## Aufbau

```
git push  ──►  GitHub (drastischmode/co-glitch, kanonisch)
                   │
                   │  Pull-Mirror, Intervall 15 min
                   │  (oder sofort via ~/bin/coglitch-ci-sync.sh)
                   ▼
             Forgejo auf oracle-vps (easydoesit/co-glitch, tailnet-only)
                   │  Webhook  http://woodpecker-server-1:8000/api/hook?...
                   ▼
             Woodpecker-Server (VPS)  ──gRPC 100.90.252.42:9000──►  Agent "easy-ai"
             nur Metadaten + Logs                                  baut die Pipeline
                                                                   (Label location=laptop)
```

Der VPS-Agent (`woodpecker-agent-1`) hat das Label `location=laptop` **nicht** und kann
Workflows mit diesem Label deshalb nicht annehmen. Images, Workspace und Layer-Cache
entstehen ausschließlich auf dem Laptop.

## Was auf dem VPS landet

| Posten | Größe |
|---|---|
| Forgejo-Repo (Mirror-Klon) | ~1,4 MB inkl. Datenbank/Metadaten |
| Woodpecker-Daten (`woodpecker_data`) | ~400 KB (SQLite + Logdateien) |
| Build-Images / Workspaces | 0 B (laufen auf dem Laptop) |

Logs werden mit `WOODPECKER_LOG_STORE=file` (Pfad `/var/lib/woodpecker/logs`) statt in
SQLite geschrieben, damit die Datenbank nicht mit jedem Build wächst.

## Pipeline

`.woodpecker.yml` im Repo, Schritte:

1. `bash-syntax` – `bash -n` für alle Skripte
2. `shellcheck` – `--severity=warning --exclude=SC2034` (Bestands-Findings der Stufe style/info sind ausgeblendet)
3. `yamllint` – `docker/`, `config/`, `.woodpecker.yml`
4. `compose-config` – `docker compose config --quiet` für client/voice/vps
5. `json-validate` – `jq -e` auf `config/opencode/*.json`
6. `tests` – `tests/run.sh` (Redis-Config + Health-Semantik)

Lokal prüfen, ohne Pipeline-Lauf:

```bash
docker run --rm -v "$PWD:/repo" woodpeckerci/woodpecker-cli:v3 lint /repo/.woodpecker.yml
```

## Bedienung

```bash
git pushci          # git push + sofortiger Mirror-Sync (CI startet in Sekunden)
git push            # CI startet spätestens nach dem 15-min-Mirror-Intervall
~/bin/coglitch-ci-sync.sh   # nur den Mirror-Sync anstoßen
```

Der nächtliche `git-sync.timer` ruft `coglitch-ci-sync.sh` nach einem erfolgreichen
Push automatisch auf (Log: `~/projects/git-sync.log`, Zeile `ci-sync ok: co-glitch`).

## Bekannte Grenzen

- **Pull Requests**: gespiegelt werden Branches/Tags, keine PRs. CI für PR-Events
  läuft nur, wenn der PR in Forgejo gestellt wird.
- **Mirror ist read-only**: direktes Pushen nach Forgejo wird mit
  `mirror repository is read-only` abgelehnt. GitHub bleibt die Quelle.
- **Laptop muss laufen**: Ist der Agent offline, bleibt die Pipeline in der Warteschlange
  (kein Fallback auf den VPS-Agenten – das ist Absicht).

## Server-/Forgejo-Konfiguration (VPS, `~/projects/...`)

Woodpecker (`~/projects/woodpecker/docker-compose.yml`):
- `100.90.252.42:8000` (UI) und `100.90.252.42:9000` (gRPC, für den Laptop-Agent) – nur Tailnet
- `WOODPECKER_EXPERT_WEBHOOK_HOST=http://woodpecker-server-1:8000` (Forgejo liefert Hooks im Docker-Netz aus)
- `WOODPECKER_LOG_STORE=file`, `WOODPECKER_LOG_STORE_FILE_PATH=/var/lib/woodpecker/logs`
- `WOODPECKER_RETRY_TIMEOUT=0` beim Agenten (reconnectet dauerhaft)

Forgejo (`~/projects/forgejo/docker-compose.yml`):
- `FORGEJO__webhook__ALLOWED_HOST_LIST=woodpecker-server-1` (sonst verwirft Forgejo die Hook-Zustellung)
- Netzwerk-Alias `oracle-vps.taile5efea.ts.net` auf `forgejo_default`, damit der Woodpecker-Server
  die konfigurierte Forgejo-URL auch aus dem Container erreicht

Laptop-Agent: `~/woodpecker-agent/docker-compose.yml` (Label `location=laptop`, `.env` mit 600).

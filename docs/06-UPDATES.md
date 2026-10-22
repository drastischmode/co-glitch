# Updates & Wartung

## Update-Strategie

co-glitch nutzt einen **rolling update** Ansatz:
1. Git-Repository aktualisieren
2. Docker Images neu pullen
3. Container rolling neu starten
4. Healthchecks validieren

## Update durchführen

```bash
# Standard-Update (mit Git-Check)
make update

# Force-Update (verwirft lokale Änderungen)
./scripts/update.sh --force
```

### Was passiert bei `make update`?

1. **Git Pull** - Repository aktualisieren (bricht ab bei lokalen Änderungen ohne `--force`)
2. **Docker Pull** - Alle Images neu laden (`docker compose pull`)
3. **Rolling Restart** - Container nacheinander neu starten (`docker compose up -d --remove-orphans`)
4. **Healthcheck** - Wartet bis alle Services `healthy` sind (max 120s)
5. **Cleanup** - Nicht genutzte Images entfernen (`docker image prune -f`)

## Update-Checkliste

### Vor dem Update
- [ ] Backup erstellen: `make backup`
- [ ] Changelog prüfen: `git log --oneline -10`
- [ ] Breaking Changes in Release Notes prüfen

### Nach dem Update
- [ ] `make client-health` - Alle Services healthy?
- [ ] `make validate-models` - AI-Endpunkte erreichbar?
- [ ] Logs prüfen: `docker compose -f docker/client/docker-compose.yml logs --tail=50`
- [ ] Funktionstest: n8n, Forgejo, Postiz, Supabase aufrufen

## Rollback

Falls Update Probleme verursacht:

```bash
# 1. Git zurücksetzen
git log --oneline -5
git checkout <vorheriger-commit-hash>

# 2. Images zurückziehen (falls Tags genutzt)
docker compose -f docker/client/docker-compose.yml pull

# 3. Neu starten
make down-client && make up-client

# Oder komplettes Restore aus Backup
make restore DATE=2026-10-21
```

## Image-Tagging Strategie

| Service | Tag-Strategie | Beispiel |
|---------|---------------|----------|
| n8n | Minor-Version | `1.82.0` |
| Forgejo | Major-Version | `9` |
| Postiz | Release-Tag | `v0.5.0` |
| Supabase DB | Patch-Version | `15.8.1.060` |
| Kong | Minor-Version | `2.8.1` |
| Uptime Kuma | Minor-Version | `1.23.16` |
| Dozzle | Version | `v7.3.0` |
| Beszel | Version | `v0.12.0` |
| cAdvisor | Version | `v0.49.1` |
| DIUN | Version | `v5.12.0` |
| Ollama | Version | `0.5.12` |
| Whisper | `latest` (bewusst) | `latest` |

> **Hinweis**: `dozzle`, `diun`, `ollama`, `whisper` nutzen bewusst `:latest` da sie häufige Updates ohne Breaking Changes erhalten. Für produktive Umgebungen können diese in der `.env` auf feste Versionen gepinnt werden.

## Automatische Updates (Renovate)

```json
// renovate.json
{
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchFileNames": ["docker/**/docker-compose.yml"],
      "matchDatasources": ["docker"],
      "groupName": "docker-images",
      "automerge": false,
      "schedule": ["after 2am on monday"]
    }
  ],
  "docker": {
    "fileMatch": ["docker/**/docker-compose.yml"]
  }
}
```

Renovate erstellt automatisch PRs für Docker Image Updates. Bei Major-Updates manuell prüfen!

## Wartungsfenster

Empfohlen: **Wöchentlich** (z. B. Montags 02:00-04:00)

```bash
# Cron-Job für automatisches Update
echo "0 2 * * 1 cd /home/admin/co-glitch && make update >> /var/log/co-glitch-update.log 2>&1" | sudo crontab -
```

## Häufige Update-Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| `git pull` schlägt fehl | Lokale Änderungen | `git stash` oder `--force` |
| Container startet nicht | Image-Breaking-Change | Logs prüfen, ggf. Config anpassen |
| Healthcheck timeout | DB-Migration dauert | `start_period` erhöhen, Logs prüfen |
| `docker compose pull` fehlschlägt | Registry-Rate-Limit | `docker login`, warten, retry |
| Port-Konflikt nach Update | Port geändert | `docker compose config` prüfen, `.env` anpassen |

## Versionierung

co-glitch nutzt **Semantic Versioning** für das Repository:

- **Major**: Breaking Changes (Config-Struktur, Breaking Image-Updates)
- **Minor**: Neue Features, neue Services, nicht-brechende Updates
- **Patch**: Bugfixes, Security-Updates, Dokumentation

Aktuelle Version: siehe `CHANGELOG.md`
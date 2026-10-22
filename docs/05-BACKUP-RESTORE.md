# Backup & Restore

## Übersicht

Das Backup-System sichert alle persistenten Daten des co-glitch Client Stacks:
- **PostgreSQL** (Supabase DB) via `pg_dump`
- **Docker Volumes** (n8n, Forgejo, Postiz, Uptime Kuma, Beszel, Ollama) via `tar.gz`

## Backup erstellen

```bash
# Standard-Backup (heutiges Datum)
make backup

# Backup in benutzerdefiniertes Verzeichnis
./scripts/backup.sh ./my-backups/2026-10-22-manual
```

### Was wird gesichert?

| Quelle | Format | Dateiname |
|--------|--------|-----------|
| Supabase PostgreSQL | SQL Dump | `supabase_db_YYYYMMDD-HHMMSS.sql` |
| n8n Data | tar.gz | `n8n_data_YYYYMMDD-HHMMSS.tar.gz` |
| Forgejo Data | tar.gz | `forgejo_data_YYYYMMDD-HHMMSS.tar.gz` |
| Postiz Data | tar.gz | `postiz_data_YYYYMMDD-HHMMSS.tar.gz` |
| Uptime Kuma | tar.gz | `kuma_data_YYYYMMDD-HHMMSS.tar.gz` |
| Beszel Data | tar.gz | `beszel_data_YYYYMMDD-HHMMSS.tar.gz` |
| Ollama Models | tar.gz | `ollama_data_YYYYMMDD-HHMMSS.tar.gz` |
| Kong Config | YAML | `supabase-kong.yml` |
| Environment | Shell | `env_backup_YYYY-MM-DD` |
| Manifest | Text | `MANIFEST_YYYYMMDD-HHMMSS.txt` |

### Ausgabe

```
=== co-glitch Backup ===
Backup-Verzeichnis: ./backups/2026-10-22
Timestamp: 20261022-143052
1. PostgreSQL Dump erstellen...
   ✓ supabase_db_20261022-143052.sql
2. Docker Volumes sichern...
   ✓ n8n_data_20261022-143052.tar.gz
   ✓ forgejo_data_20261022-143052.tar.gz
   ...
5. Manifest erstellen...
=== Backup abgeschlossen ===
Backup liegt in: ./backups/2026-10-22
```

## Restore durchführen

```bash
# Restore aus heutigem Backup
make restore DATE=2026-10-22

# Oder direkt
./scripts/restore.sh 2026-10-22
```

### Ablauf

1. **Bestätigung** (Abbruch möglich)
2. **Stack stoppen** (`make down-client`)
3. **PostgreSQL restore** (via `psql`)
4. **Volumes restore** (Volumes löschen, neu erstellen, `tar xzf`)
5. **Kong Config restore**
6. **Optional: .env restore**
7. **Stack starten** (`make up-client`)

### Wichtig

- **Restore überschreibt ALLE aktuellen Daten!**
- Backup muss mit `make backup` oder `scripts/backup.sh` erstellt worden sein
- Bei manuellen Backups: Struktur muss identisch sein
- Restore dauert je nach Datenmenge 1-5 Minuten

## Automatisierung (systemd Timer)

```bash
# Timer aktivieren (täglich 03:00)
make backup-enable

# Timer Status prüfen
systemctl --user status backup.timer
systemctl --user status backup.service

# Logs
journalctl --user -u backup.service -f
```

### Manuelle Timer-Installation

```bash
# Service & Timer nach ~/.config/systemd/user/ kopieren
mkdir -p ~/.config/systemd/user
cp config/systemd/backup.service config/systemd/backup.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now backup.timer
```

## Retention

- Standard: 7 Tage (alte Backups manuell löschen)
- Konfigurierbar in `scripts/backup.sh` (Variable `RETENTION_DAYS`)

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| `pg_dump: connection refused` | `supabase-db` muss `healthy` sein (`make client-health` prüfen) |
| `tar: /data: Cannot open` | Volume Name prüfen (`docker volume ls \| grep co-glitch-client`) |
| Restore schlägt fehl | Stack muss gestoppt sein (`make down-client` vor Restore) |
| `.env` nicht restored | Manuell prüfen: `cat backups/2026-10-22/env_backup_2026-10-22` |

## Offsite-Backup (rclone)

```bash
# rclone konfigurieren (einmalig)
rclone config
# Name: remote, Type: s3/b2/gdrive/etc.

# Backup zu Remote syncen
rclone sync ./backups/2026-10-22 remote:co-glitch-backups/2026-10-22 --progress

# Automatisch via Cron
echo "0 4 * * * rclone sync ./backups/ remote:co-glitch-backups/ --progress" | crontab -
```
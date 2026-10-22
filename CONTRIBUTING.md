# Contributing to co-glitch

Danke für dein Interesse an co-glitch! Dieses Dokument beschreibt, wie du zum Projekt beitragen kannst.

## Verhaltenskodex

Sei respektvoll, konstruktiv und inklusiv. Wir tolerieren keine Belästigung, Diskriminierung oder toxisches Verhalten.

## Wie du beitragen kannst

### Bug Reports
1. Prüfe, ob der Bug bereits in den [Issues](https://github.com/.../issues) gemeldet ist
2. Erstelle ein neues Issue mit:
   - Klare Beschreibung des Problems
   - Schritte zur Reproduktion
   - Erwartetes vs. tatsächliches Verhalten
   - Logs/Screenshots (falls relevant)
   - Umgebung: OS, Docker Version, co-glitch Commit Hash

### Feature Requests
1. Prüfe, ob das Feature bereits geplant ist
2. Erstelle ein Issue mit:
   - Klare Beschreibung des Features
   - Use Case / Motivation
   - Mögliche Implementierungsideen
   - Breaking Changes?

### Pull Requests
1. Fork das Repository
2. Erstelle einen Branch: `git checkout -b feature/mein-feature`
3. Mache deine Änderungen
4. Führe Tests aus: `make doctor`
5. Commit mit konventioneller Nachricht (siehe unten)
6. Push und erstelle PR

## Commit-Konventionen

Wir nutzen [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types
- `feat`: Neues Feature
- `fix`: Bugfix
- `docs`: Dokumentation
- `style`: Formatierung (whitespace, etc.)
- `refactor`: Code-Umstrukturierung ohne funktionale Änderung
- `perf`: Performance-Verbesserung
- `test`: Tests hinzufügen/ändern
- `chore`: Build-Prozess, Dependencies, etc.
- `security`: Sicherheits-Fix

### Beispiele
```
feat(client): add beszel-agent healthcheck
fix(docker): resolve wget missing in postiz healthcheck
docs(readme): update quickstart with backup commands
chore(deps): pin postiz image to v0.5.0
```

## Branch-Namen

```
feature/<kurzbeschreibung>
fix/<kurzbeschreibung>
docs/<kurzbeschreibung>
chore/<kurzbeschreibung>
```

Beispiele:
- `feature/add-backup-restore`
- `fix/postiz-healthcheck-wget-missing`
- `docs/update-security-guide`

## Code Style

### Shell Scripts
- `shellcheck` muss ohne Fehler durchlaufen (`make doctor` prüft das)
- Shebang: `#!/bin/bash`
- `set -euo pipefail` am Anfang
- Funktionen für wiederverwendbare Logik
- Kommentare für komplexe Logik

### Docker Compose
- Images gepinnt (kein `:latest` außer dokumentierte Ausnahmen)
- Healthchecks für alle Services mit HTTP/DB-Endpunkten
- `depends_on: condition: service_healthy` für DB-Abhängigkeiten
- Resource Limits (`deploy.resources`) gesetzt
- Capability Dropping (`cap_drop: [ALL]`, minimales `cap_add`)
- Non-root User wo möglich
- Security Options: `no-new-privileges:true`

### JSON/YAML
- 2 Spaces Einrückung
- Trailing commas wo erlaubt
- Keine trailing whitespace

## Testing

Vor jedem PR:
```bash
# Vollständiger Check
make doctor

# Einzelne Checks
shellcheck scripts/*.sh
yamllint docker/ config/ .github/
docker compose -f docker/client/docker-compose.yml config --quiet
docker compose -f docker/voice/docker-compose.yml config --quiet
docker compose -f docker/vps/docker-compose.yml config --quiet
gitleaks detect --verbose
```

## Release Process

1. Version in `CHANGELOG.md` eintragen
2. Tag erstellen: `git tag -a v1.2.3 -m "Release v1.2.3"`
3. Push: `git push origin v1.2.3`
4. GitHub Release erstellen mit Changelog-Auszug

## Fragen?

Bei Fragen: Issue erstellen oder in Discussions fragen.
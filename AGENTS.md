
## Doku-Divergenz - Dienste-Inventar

**Hintergrund:** Die alte Doku behauptete "12 Dienste im Client-Stack". Ausgelagert aus
dem system-diff-Plan (P3.10 / SD-12).

### Tatsaechliche Dienste (aus `docker ps` auf dem VPS)

Stand: 2026-10-28 - **31 laufende Container**.

```
beszel
beszel-agent
cadvisor-cadvisor-1
diun
dozzle-dozzle-1
forgejo-db-1
forgejo-forgejo-1
n8n-n8n-1
postiz
postiz-edge
postiz-postgres
postiz-redis
realtime-dev.supabase-realtime
spotlight
supabase-auth
supabase-db
supabase-edge-functions
supabase-envoy
supabase-imgproxy
supabase-meta
supabase-pooler
supabase-rest
supabase-storage
supabase-studio
temporal
temporal-admin-tools
temporal-elasticsearch
temporal-postgresql
temporal-ui
uptime-kuma-uptime-kuma-1
woodpecker-server-1
```

### Behauptete Dienste (alte Doku)

- [ ] Liste aus alter Doku extrahieren und hier eintragen
- [ ] Abgleich: welche fehlen, welche sind neu

### Offene Punkte

- [ ] Dienste-Inventar vervollstaendigen
- [ ] Alte Doku aktualisieren oder archivieren
- [ ] Klaeren, ob "Client-Stack" Zielarchitektur oder Ist-Zustand meint

## Decisions
- 2026-10-28: CI-Mirror-Sync wird nur noch bei SHA-Ungleichheit getriggert (GitHub-HEAD vs. Forgejo-HEAD, fail-open, --force zum Umgehen) — das Skript hat kein git push --mirror, ein HEAD_BEFORE-Patch waere wirkungslos. Ausserdem: Doku-Divergenz ist dokumentiert (31 Container real vs. Claim '12 Dienste'), PAT-Rotation steht in docs/07-SECURITY.md.

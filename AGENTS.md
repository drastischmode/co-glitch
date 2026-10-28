
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
- 2026-10-28: Supabase-API laeuft seit 2026-10-28 auch auf dem Client (Easy-AI): auth/rest/storage+imgproxy/realtime im Profil 'client', Kong im Default-Profil, JWT-Pruefung in den Diensten statt key-auth im Gateway. Edge Functions und Studio bleiben VPS-only (bewusst, um den Client-Stack schlank zu halten).
- 2026-10-28: CI-Mirror-Sync wird nur noch bei SHA-Ungleichheit getriggert (GitHub-HEAD vs. Forgejo-HEAD, fail-open, --force zum Umgehen) — das Skript hat kein git push --mirror, ein HEAD_BEFORE-Patch waere wirkungslos. Ausserdem: Doku-Divergenz ist dokumentiert (31 Container real vs. Claim '12 Dienste'), PAT-Rotation steht in docs/07-SECURITY.md.

## Learnings
- 2026-10-28: Supabase self-host Fallstricke (2026-10-28): (1) SUPABASE_DB_PASS mit '"' zerlegt .env und die postgres://-URLs -> URL-sicheres Passwort verwenden; (2) Rollen supabase_auth_admin/authenticator/supabase_storage_admin haben eigene Passwoerter, 'authenticator' ist reserved role (nur Superuser) -> als supabase_admin ueber TCP aendern (pg_hba: host 127.0.0.1 trust); (3) realtime v2 leitet den Tenant aus dem HOST-Header ab (erstes Label, z.B. realtime-dev) und liefert WS nur unter /socket/websocket -> Kong-Service-Pfad /socket + request-transformer Host-Header (Kong 2.8 kennt kein host_header) + Container-Hostname; (4) realtime braucht das Schema _realtime, sonst 'no schema has been selected'.

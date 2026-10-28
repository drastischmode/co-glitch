# 12 — Secrets mit sops + age

**Status:** aktiv seit 2026-10-28 (system-diff P3.8, Entscheidung „sops überall").

## Architektur

Ein einziger age-Key und eine einzige Secret-Datei gelten auf **beiden** Hosts:

| Element | Workstation (EASY-AI) | VPS (oracle-vps) |
|---|---|---|
| Privater age-Key | `~/.config/sops/age/keys.txt` (600) | `~/.config/sops/age/keys.txt` (600) |
| Secret-Datei | `~/.config/sops/secrets.enc.yaml` | `~/.config/sops/secrets.enc.yaml` |
| sops | 3.13.3 | 3.13.3 (arm64-deb) |
| age | 1.x (pacman) | 1.1.1 (apt, Ubuntu 24.04) |

Public Key: `age1rq0jtcr849emmxw6ntp5w2epxx953gm7ng3hvnnu03npm9465sask0ufrq`

Beide Kopien der `secrets.enc.yaml` sind byte-identisch — nach jeder Änderung muss
die Datei auf den anderen Host synchronisiert werden:

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
scp ~/.config/sops/secrets.enc.yaml oracle-vps:~/.config/sops/secrets.enc.yaml
ssh oracle-vps 'chmod 600 ~/.config/sops/secrets.enc.yaml'
# Gegenprobe: Hashes muessen gleich sein
sha256sum ~/.config/sops/secrets.enc.yaml
ssh oracle-vps 'sha256sum ~/.config/sops/secrets.enc.yaml'
```

## Bewusster Trade-off

„sops überall" wurde gewählt, um **einen** manuellen Keygen-Schritt zu sparen.
Der Preis: eine VPS-Kompromittierung leakt **alle** Secrets, nicht nur VPS-lokale.
Ein separates `secrets-vps.enc.yaml` mit eigenem Key existiert bewusst nicht.

## Täglicher Gebrauch

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

sops -d ~/.config/sops/secrets.enc.yaml            # alles (Vorsicht: Klartext im Terminal)
sops -d --extract '["GITHUB_TOKEN_DRASTISCHMODE"]' ~/.config/sops/secrets.enc.yaml
sops edit ~/.config/sops/secrets.enc.yaml          # interaktiv aendern
```

Schluessel entfernen/hinzufuegen **ohne** Editor:

```bash
sops unset ~/.config/sops/secrets.enc.yaml '["ALTER_KEY"]'
sops set   ~/.config/sops/secrets.enc.yaml '["NEUER_KEY"]' '"wert"'
```

Der Git-Credential-Helper `~/bin/git-credential-drastischmode.sh` liest
`GITHUB_TOKEN_DRASTISCHMODE`. Er ist auf beiden Hosts rein sops-basiert —
**kein** `env.sh`-Fallback mehr.

## Backup-Konvention (wichtig)

Backups **müssen** auf `.yaml` enden, sonst kann sops sie nicht mehr lesen:

```bash
cp -a ~/.config/sops/secrets.enc.yaml ~/.config/sops/secrets.enc.yaml.bak.$(date +%s).yaml
```

**Gotcha:** `sops -d secrets.enc.yaml.bak.1793197709` scheitert mit
`Could not unmarshal input data`, weil sops das Format an der Dateiendung
erkennt. `--input-type yaml` hilft nicht. Rollback funktioniert nur über
eine `.yaml`-Endung oder durch Zurückkopieren auf den Originalnamen:

```bash
cp ~/.config/sops/secrets.enc.yaml.bak.<ts>.yaml /tmp/rollback.yaml
cp /tmp/rollback.yaml ~/.config/sops/secrets.enc.yaml
```

Aufbewahrung: 7 Tage, dann `shred -u`.

## Verifikation nach jeder Aenderung

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# 1. Datei entschluesselt (Key-Anzahl statt Werte)
sops -d ~/.config/sops/secrets.enc.yaml | grep -cE '^[A-Z_]+:'

# 2. Erwarteter Schluessel vorhanden
sops -d --extract '["GITHUB_TOKEN_DRASTISCHMODE"]' ~/.config/sops/secrets.enc.yaml >/dev/null && echo OK

# 3. Helper liefert Credentials (Wert redigiert)
printf 'protocol=https\nhost=github.com\n\n' | ~/bin/git-credential-drastischmode.sh | sed 's/^password=.*/password=<REDACTED>/'

# 4. Beide Hosts identisch
sha256sum ~/.config/sops/secrets.enc.yaml
ssh oracle-vps 'sha256sum ~/.config/sops/secrets.enc.yaml'
```

## Drift-Report

`~/bin/env-diff-report.sh` (Cron: So 05:00, Log `~/logs/env-diff.log`) vergleicht
wöchentlich nur die **Variablennamen** der `env.sh` beider Hosts, nie die Werte.
Bewusst host-lokale Variablen (`BOT_WORKDIR`, `BOT_LAPTOP_WORKDIR`) sind im
Skript allowlistet — Werte sind host-spezifische Pfade, keine Drift.

Versand läuft über Resend von `onboarding@resend.dev` (Domain `easydoesit.online`
ist bei Resend nicht verifiziert und nicht delegiert). Empfänger ist
`SENDER_EMAIL_ADDRESS`, also `easydoesit.online.welt@gmail.com`. Eine eigene
Absenderdomain ist bewusst nicht angestrebt; `RESEND_FROM` kann sie bei Bedarf
überschreiben.

## Secrets, die bewusst NICHT in env.sh stehen

Credential-Werte gehören nicht in `env.sh` (wird von vielen Tools gesourct, landet
damit in jeder Prozess-Umgebung). Aktuell betrifft das:

| Key | Zugriff |
|---|---|
| `WOODPECKER_TOKEN` | `sops -d --extract '["WOODPECKER_TOKEN"]' ~/.config/sops/secrets.enc.yaml` |
| `SENDER_EMAIL_ADDRESS` | dito (kein Geheimnis, aber single source of truth) |

Beispiel für einen API-Check ohne Klartext-Datei:

```bash
T=$(sops -d --extract '["WOODPECKER_TOKEN"]' ~/.config/sops/secrets.enc.yaml)
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $T" http://100.90.252.42:8000/api/user
unset T
```

## Rotation

Siehe [07-SECURITY.md](07-SECURITY.md) → „GitHub-PAT-Rotation".

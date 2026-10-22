# v1.0.4-pending – Verification Report

Datum: 2026-10-22T12:38:47Z
Basis: v1.0.3 (67751f8, unverändert)

## Status

- Backup: verifiziert. DB-Dump (forgejo, 121 Tabellen, 22021 Bytes), 4 Volume-Tarballs, manifest.sha256 mit 6 Einträgen.
- Voice-Stack: nicht auf frischer VM getestet.
- Arch: nicht getestet (kein qemu-aarch64).
- Piper-TTS: kein Audio-Device auf Host.

## Was geschlossen wurde

- backup.sh im richtigen Repo (/home/admin/co-glitch) neu geschrieben, alle DBs + 4 Volumes.
- forgejo-Migration: INSTALL_LOCK=true, echtes DB-Passwort, Migration als git-User.
- forgejo-DB: 0 → 121 Tabellen, Dump 404 → 22021 Bytes.

## Was NICHT geschlossen wurde

- Voice-Stack auf VM.
- Arch.
- Piper-TTS (kein Audio-Device).

## Konsequenz

- Kein v1.0.4-Tag. v1.0.3 bleibt 67751f8.
- README-Badge bleibt stable (voice unverified).
- Nächster Schritt: VM für Voice/Arch. Backup ist abgeschlossen.

## Git-Forensik: v1.0.3 Tag-Objekt vs. Commit

- v1.0.3 ist ein annotiertes Tag-Objekt: `2c713432c597f5f8eaf81afa239a618a290962b0`
- Ziel-Commit: `67751f8dc8559aa1ac43df75b15d42ea1ff2445d`
- `git rev-parse --short v1.0.3` → `2c71343` (Tag-Objekt)
- `git rev-parse v1.0.3^{commit}` → `67751f8` (Commit)
- Kein Drift: `git log 67751f8..v1.0.3` und `git diff 67751f8 v1.0.3` sind leer.
- Frühere Berichte, die „v1.0.3 = 67751f8" sagten, meinten den Ziel-Commit – korrekt.
- Frühere Berichte, die „v1.0.3 = 2c71343" sagten, meinten das Tag-Objekt – ebenfalls korrekt.
- Kein Retag, keine Manipulation.

## Whisper-Test lokal (ohne VM) – 2026-10-22

- Service: `onerahmet/openai-whisper-asr-webservice:latest` (Model: base)
- Container startet, API erreichbar auf 127.0.0.1:8081
- Endpunkte: `/asr` (Transkription), `/detect-language` (Spracherkennung), `/docs`, `/openapi.json`
- Healthcheck in docker-compose.yml fehlerhaft: `/health` gibt 404 (korrekt: `/asr` oder Root)
- Transkription: HTTP 200, leere Antwort für Sinus-Signal (erwartet – keine Sprache)
- Spracherkennung: funktioniert, liefert JSON (`detected_language`, `confidence`)
- Fazit: Whisper **läuft lokal**, nur Healthcheck-Pfad in Compose-Datei anpassen

### Offene Voice-Punkte nach Whisper-Test

| Komponente | Status | Grund |
|------------|--------|-------|
| Whisper (STT) | ✅ lokal | Service funktionsfähig, Healthcheck-Pfad fixen |
| Piper (TTS) | ⚠️ | Binary nicht installiert, Modell vorhanden |
| Voice-VM-Test | ⚠️ | Kein multipass/lima, qemu-x86 verfügbar aber nicht genutzt |
| Arch-Test | ⚠️ | Kein qemu-aarch64 |


# v1.0.4-pending – Verification Report

Datum: 2026-10-22T12:38:47Z
Basis: v1.0.3 (67751f8, unverändert)

## Status

- Backup: verifiziert. DB-Dump (forgejo, 121 Tabellen, 22021 Bytes), 4 Volume-Tarballs, manifest.sha256 mit 6 Einträgen.
- Voice-Stack: nicht auf frischer VM getestet.
- Arch: nicht getestet (kein qemu-aarch64).
- Piper (TTS): ✅ lokal verifiziert (WAV erzeugt, Binary in /opt/piper-tts/piper, Modell de_DE-thorsten-medium).

## Was geschlossen wurde

- backup.sh im richtigen Repo (/home/admin/co-glitch) neu geschrieben, alle DBs + 4 Volumes.
- forgejo-Migration: INSTALL_LOCK=true, echtes DB-Passwort, Migration als git-User.
- forgejo-DB: 0 → 121 Tabellen, Dump 404 → 22021 Bytes.
- Whisper (STT): ✅ lokal – Service `onerahmet/openai-whisper-asr-webservice:latest` (Model: base), API auf 127.0.0.1:8081, Healthcheck gefixt.
- Piper (TTS): ✅ lokal – `piper-tts-bin` via AUR installiert (Binary: /opt/piper-tts/piper), Modell `de_DE-thorsten-medium.onnx` heruntergeladen, WAV-Erzeugung via `--output_file` funktionsfähig (78 KB, 22.05 kHz, 16-bit mono).

## Was NICHT geschlossen wurde

- Voice-Stack auf VM (Integrationstest Whisper + Piper zusammen).
- Arch-Test (kein qemu-aarch64).

## Konsequenz

- Kein v1.0.4-Tag. v1.0.3 bleibt 67751f8.
- README-Badge bleibt stable (voice unverified).
- Nächster Schritt: VM für Voice/Arch Integrationstest. Backup ist abgeschlossen.

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

## Piper-Test lokal (ohne VM) – 2026-10-22

- Paket: `piper-tts-bin` 2023.11.14-1 (AUR, via yay)
- Binary: `/opt/piper-tts/piper` (nicht in PATH, muss voll qualifiziert oder via Symlink aufgerufen werden)
- Modell: `de_DE-thorsten-medium.onnx` (63 MB) + `.json` von HuggingFace (rhasspy/piper-voices)
- Test: `echo "Hallo, dies ist ein Test." | /opt/piper-tts/piper --model ~/.local/share/piper-voices/de_DE-thorsten-medium.onnx --output_file /tmp/piper-test.wav`
- Ergebnis: RC=0, WAV 78496 Bytes, RIFF WAVE, 16-bit mono, 22050 Hz, Real-time factor 0.045
- Espeak-ng-Daten: `/opt/piper-tts/espeak-ng-data/` (vom Paket mitgeliefert)
- Fazit: Piper **läuft lokal**, WAV-Erzeugung funktioniert ohne Audio-Device

### Offene Voice-Punkte nach Whisper + Piper Tests

| Komponente | Status | Grund |
|------------|--------|-------|
| Whisper (STT) | ✅ lokal | Service funktionsfähig, Healthcheck-Pfad gefixt |
| Piper (TTS) | ✅ lokal | Binary + Modell funktionsfähig, WAV-Erzeugung OK |
| Voice-VM-Test | ⚠️ | Kein multipass/lima |
| Arch-Test | ⚠️ | Kein qemu-aarch64 |

## Endzustand 2026-10-22T13:17:40Z

- Branch: v1.0.4-pending-work
- HEAD: b43e4d1
- v1.0.3 unverändert: Tag-Objekt 2c71343 → Commit 67751f8
- Working Tree: clean=no

### Abgeschlossen
- Backup: scripts/backup.sh syntaktisch ok, forgejo-Dump vorhanden, 4 Volumes, Manifest + SHA256.
- forgejo: 121 Tabellen, Migration abgeschlossen.
- Whisper (STT): lokal ✅, Healthcheck /docs 200.
- Piper (TTS): lokal ✅, WAV erzeugt (78.5 KB, 16-bit mono 22050 Hz).

### Ehrlich offen (Infrastruktur, nicht Code)
- Voice-VM-Test: keine VM auf Host (kein multipass/lima).
- Arch-Test: kein qemu-aarch64.

### Entscheidung
- Kein v1.0.4-Tag. v1.0.3 bleibt 67751f8.
- Badge bleibt stable (voice unverified) bis VM-Test vorliegt.
- Nächster Schritt: multipass/lima installieren oder qemu-x86 für Voice-Integrationstest nutzen.

## Nachtrag 2026-10-27T09:15:18Z – v1.0.4 Release

- v1.0.4 getaggt: 8149649 (Tag-Objekt d4b7f0c)
- EDA-Integration committet (KiCad, QElectroTech, ngspice, LibreCAD, FreeCAD)
- Omarchy OS-Detection + UFW-Healthcheck (systemctl, kein TTY) committet
- Alle 4 AI-Provider HTTP 200 (Zen, NVIDIA, z.ai, Ollama)
- git-sync-005 gelöst (PAT Scope erweitert)
- Voice-VM (Whisper): ⚠️ nicht verifiziert – Grund: skip_no_multipass
- Arch-VM: ⚠️ ausstehend (kein qemu-aarch64, nichts installiert)
- Piper lokal: ✅ bereits getestet (v1.0.4-pending)
- v1.0.3 unverändert: 67751f8

## Nachtrag 2026-10-27T12:30:00Z – EDA-Tools vollständig installiert

- Ausführung: `pkexec pacman -S --needed --noconfirm librecad freecad` (kein TTY nötig, Polkit-Agent läuft, laut conventions.md).
- install-eda (Commit c03328f): per-Tool, skip-wenn-vorhanden, qelectrotech AUR-Fallback.
- Verifikation: kicad, qelectrotech, ngspice, librecad, freecad alle als Binary vorhanden.
- v1.0.4-Tag unverändert (8149649). Kein Retag, keine neuen Tags.

### EDA-Status: ✅ vollständig (alle 5 Tools).

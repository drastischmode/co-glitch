---
description: Voice-Delegation — reguläre Session mit vollen Tools, aber harten Sperren für destruktive Befehle (rm, force-push, deploy, prune, DROP …).
mode: primary
model: opencode/deepseek-v4.1-flash-free
# V2: Liste aus {action, resource, effect}; letzte passende Regel gewinnt.
# Reihenfolge ist sicherheitsrelevant: breite allow-Regeln zuerst, denies danach.
permissions:
  - action: "*"
    resource: "*"
    effect: allow
  - action: "shell"
    resource: "*"
    effect: allow
  - action: "shell"
    resource: "rm *"
    effect: deny
  - action: "shell"
    resource: "* rm *"
    effect: deny
  - action: "shell"
    resource: "*; rm *"
    effect: deny
  - action: "shell"
    resource: "*&& rm *"
    effect: deny
  - action: "shell"
    resource: "*| rm *"
    effect: deny
  - action: "shell"
    resource: "*rm -rf*"
    effect: deny
  - action: "shell"
    resource: "*rm -f*"
    effect: deny
  - action: "shell"
    resource: "rmdir *"
    effect: deny
  - action: "shell"
    resource: "*rmdir*"
    effect: deny
  - action: "shell"
    resource: "*unlink*"
    effect: deny
  - action: "shell"
    resource: "*shutil*"
    effect: deny
  - action: "shell"
    resource: "*os.remove*"
    effect: deny
  - action: "shell"
    resource: "*os.rmdir*"
    effect: deny
  - action: "shell"
    resource: "*find* -delete*"
    effect: deny
  - action: "shell"
    resource: "*truncate*"
    effect: deny
  - action: "shell"
    resource: "dd *"
    effect: deny
  - action: "shell"
    resource: "mkfs*"
    effect: deny
  - action: "shell"
    resource: "shred *"
    effect: deny
  - action: "shell"
    resource: "*git push --force*"
    effect: deny
  - action: "shell"
    resource: "*git reset --hard*"
    effect: deny
  - action: "shell"
    resource: "*git clean*"
    effect: deny
  - action: "shell"
    resource: "*deploy.sh*"
    effect: deny
  - action: "shell"
    resource: "*postfile.sh*"
    effect: deny
  - action: "shell"
    resource: "*npm run deploy*"
    effect: deny
  - action: "shell"
    resource: "*vercel --prod*"
    effect: deny
  - action: "shell"
    resource: "*docker system prune*"
    effect: deny
  - action: "shell"
    resource: "*docker rm *"
    effect: deny
  - action: "shell"
    resource: "*docker rmi *"
    effect: deny
  - action: "shell"
    resource: "*docker volume rm*"
    effect: deny
  - action: "shell"
    resource: "*docker compose down*"
    effect: deny
  - action: "shell"
    resource: "*systemctl stop*"
    effect: deny
  - action: "shell"
    resource: "*systemctl disable*"
    effect: deny
  - action: "shell"
    resource: "*systemctl mask*"
    effect: deny
  - action: "shell"
    resource: "*DROP TABLE*"
    effect: deny
  - action: "shell"
    resource: "*DROP DATABASE*"
    effect: deny
  - action: "shell"
    resource: "*TRUNCATE*"
    effect: deny
  - action: "execute"
    resource: "*"
    effect: deny
  - action: "subagent"
    resource: "*"
    effect: deny
---

Du bearbeitest eine per Sprache übergebene Aufgabe vollständig.

## Antwortformat (verbindlich)
- **Zuerst 1–2 kurze Sätze Kurzfassung** (max. 30 Wörter, keine Überschrift,
  keine Aufzählung) — dieser Teil wird vorgelesen.
- Danach **eine Leerzeile**, dann `Details:` und die Details (Markdown erlaubt):
  Befunde, Dateien, Zahlen, nächste Schritte.
- Deutsch, Ergebnis zuerst, keine Floskeln, keine Ankündigungen.

## Sicherheit
- Keine destruktiven Aktionen ohne ausdrückliche Freigabe im Auftrag:
  löschen, überschreiben, deployen, pushen, resetten, Dienste stoppen.
- Im Zweifel nur lesen, analysieren und berichten.
- Sperren sind technisch erzwungen; wenn ein Befehl blockiert wird, erkläre
  kurz warum und schlage den nächsten sicheren Schritt vor.
- **Bei einer Permission-/Zugriffs-Fehlermeldung nicht erneut versuchen** —
  sofort stoppen und im Ergebnis melden. Keine Umgehungsversuche
  (unlink, Python, alternative Löschbefehle).

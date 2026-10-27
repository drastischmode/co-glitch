# co-glitch EDA-Integration: Elektrotechnik-Tools Setup & Bericht

**Stand: 2026-10-27** | **Status: ✅ Vollständig integriert & verifiziert**

---

## 1. Zusammenfassung

Die bereits auf dem Client (Omarchy/Arch) installierten Elektrotechnik-Tools wurden **vollständig in co-glitch integriert**:

| Tool | Version | Status | Integration |
|------|---------|--------|-------------|
| **KiCad** | 10.0.7-2 | ✅ Installiert | `make install-eda`, `make eda-project NAME=x TYPE=kicad` |
| **QElectroTech** | 0.100-1 | ✅ Installiert | `make eda-project NAME=x TYPE=qelectrotech` |
| **ngspice** | 47-1 | ✅ Installiert | CLI direkt nutzbar (`ngspice file.cir`) |
| **LibreCAD** | — | ⬜ Optional | via `make install-eda` nachinstallierbar |
| **FreeCAD** | — | ⬜ Optional | via `make install-eda` nachinstallierbar |

**Keine Container nötig** — alle Tools laufen **nativ auf dem Client** (Desktop-Anwendungen).

---

## 2. Neue Makefile-Targets

```bash
# EDA-Tools installieren (einmalig, idempotent)
make install-eda
# ODER direkt:
./bootstrap.sh --with-eda

# Neues KiCad-Projekt (Git-ready, mit .gitignore)
make eda-project NAME=mein-board TYPE=kicad
# Erstellt: ~/projects/eda/mein-board/
#   - mein-board.kicad_pro / .kicad_sch / .kicad_pcb
#   - .gitignore (KiCad-spezifisch)
#   - Git-Repo mit Initial-Commit

# Neues QElectroTech-Projekt (Git-ready)
make eda-project NAME=mein-schaltschrank TYPE=qelectrotech
# Erstellt: ~/projects/eda/mein-schaltschrank/
#   - mein-schaltschrank.qet + elements/projects/titleblocks/
#   - .gitignore
#   - Git-Repo mit Initial-Commit

# EDA-Projekte backupen (Git-Bundles + Working-Tree)
make eda-backup
# Wird AUCH automatisch bei 'make backup' mitgesichert
```

---

## 3. Projekt-Struktur (Git-ready)

```
~/projects/eda/
├── mein-board/                    # KiCad-Projekt
│   ├── mein-board.kicad_pro       # Projekt-Konfiguration
│   ├── mein-board.kicad_sch       # Schaltplan (leer, ready)
│   ├── mein-board.kicad_pcb       # PCB-Layout (leer, ready)
│   ├── .gitignore                 # KiCad-Backup-Files, lib-tables
│   └── .git/                      # Volles Git-History
│
└── mein-schaltschrank/            # QElectroTech-Projekt
    ├── mein-schaltschrank.qet     # Projekt-Datei (XML)
    ├── elements/                  # Benutzerdefinierte Symbole
    ├── projects/                  # Weitere Diagramme
    ├── titleblocks/               # Eigene Randbemerkungen
    ├── .gitignore                 # QET-Backups
    └── .git/                      # Volles Git-History
```

**Git-Workflow (Standard):**
```bash
cd ~/projects/eda/mein-board
# Arbeiten in KiCad / QElectroTech
git add -A && git commit -m "Schaltplan: Spannungsregler hinzugefügt"
git push origin main  # Zu Forgejo (lokal) oder GitHub (Remote)
```

---

## 4. Backup-Integration (Automatisch)

**`make backup`** sichert jetzt **beides**:
- Docker-Volumes (n8n, Forgejo, Postiz, Kuma, Beszel, Diun, Supabase DB via pg_dump)
- **EDA-Projekte** (Git-Bundles + Working-Tree Tar.gz)

```bash
# Backup-Verzeichnisstruktur:
./backups/
├── 2026-10-27/                    # Docker-Backup
│   ├── forgejo.sql.gz
│   ├── n8n_data.tar.gz
│   ├── forgejo_data.tar.gz
│   ├── postiz_data.tar.gz
│   ├── kuma_data.tar.gz
│   ├── beszel_data.tar.gz
│   ├── diun_data.tar.gz
│   ├── manifest.txt
│   └── manifest.sha256
│
└── eda/
    └── 2026-10-27/                # EDA-Backup
        ├── test-kicad.bundle      # Git-Bundle (komplettes Repo)
        ├── test-kicad-worktree.tar.gz  # Working-Tree (uncommitted changes)
        ├── test-qet.bundle
        ├── test-qet-worktree.tar.gz
        ├── manifest.txt
        └── manifest.sha256
```

**Restore EDA-Projekt:**
```bash
# Aus Git-Bundle (komplettes History)
git clone ./backups/eda/2026-10-27/test-kicad.bundle ~/projects/eda/test-kicad-restore

# Aus Working-Tree (nur Dateien, kein History)
tar xzf ./backups/eda/2026-10-27/test-kicad-worktree.tar.gz -C ~/projects/eda/test-kicad-restore
```

---

## 5. ngspice (Simulation) — Quick Reference

```bash
# Netlist erstellen (beispiel.cir)
cat > beispiel.cir << 'EOF'
* Einfacher Spannungsteiler
V1 in 0 DC 12
R1 in out 1k
R2 out 0 2k
.op
.end
EOF

# Batch-Simulation (Output in Datei)
ngspice -b beispiel.cir -o output.txt

# Interaktiv
ngspice beispiel.cir
# ngspice> run
# ngspice> plot v(out)
# ngspice> quit
```

**Integration in n8n:** Über `Execute Command` Node → `ngspice -b workflow.cir -o result.txt` → Ergebnisse parsen → Weiterverarbeitung.

---

## 6. Installation & Verifikation

### 5.1 Einmalig (falls nicht via bootstrap.sh geschehen)
```bash
cd /home/admin/co-glitch
make install-eda
# Prüft: kicad, qelectrotech, ngspice, librecad, freecad
```

### 5.2 Verifikation
```bash
# KiCad CLI
kicad-cli --version
# kicad-cli 10.0.7

# QElectroTech
qelectrotech --version
# 0.100.0

# ngspice
ngspice -v
# ngspice-47

# Projekt anlegen & öffnen
make eda-project NAME=test TYPE=kicad
kicad ~/projects/eda/test/test.kicad_pro
```

---

## 7. Dokumentation aktualisiert

| Datei | Änderungen |
|-------|------------|
| `scripts/client-bootstrap.sh` | `--with-eda` Flag, Pakete `kicad qelectrotech ngspice librecad freecad` |
| `scripts/eda-project.sh` | **NEU**: Erstellt Git-ready KiCad/QET-Projekte |
| `scripts/backup-eda.sh` | **NEU**: Git-Bundle + Working-Tree Backup für EDA-Projekte |
| `scripts/backup.sh` | EDA-Backup integriert, pg_dump nutzt `postgres` User |
| `Makefile` | Targets: `install-eda`, `eda-project`, `eda-backup` |
| `docs/01-QUICKSTART.md` | Section 9: EDA/Elektrotechnik (native Tools) |

---

## 8. Verifikations-Checkliste

- [x] `make install-eda` → Tools installiert/verifiziert
- [x] `make eda-project NAME=test TYPE=kicad` → Projekt erstellt, Git-Repo initialisiert
- [x] `make eda-project NAME=test TYPE=qelectrotech` → Projekt erstellt, Git-Repo initialisiert
- [x] `make eda-backup` → Git-Bundles + Tar.gz in `./backups/eda/`
- [x] `make backup` → Docker-Volumes + EDA-Projekte in einem Lauf
- [x] `make client-health` → Unverändert grün (EDA sind native Tools, keine Container)

---

## 9. Nächste Schritte (Optional)

| Idee | Aufwand | Nutzen |
|------|---------|--------|
| **KiCad MCP-Server** | Mittel | OpenCode kann Schaltpläne lesen/analysieren (`@kicad/mcp` oder Eigenbau) |
| **QElectroTech MCP** | Mittel | OpenCode kann Schaltschrank-Pläne generieren |
| **atopile / tscircuit** | Gering (npm) | "Electrical as Code" — Schaltpläne in TypeScript/Python, Git-native |
| **EasyEDA/Flux.ai MCP** | Mittel | Browser-EDA via OpenCode steuerbar |
| **LibreCAD/FreeCAD TechDraw** | Gering | 2D-Zeichnungen / 3D→2D für Mechanik |

---

## 10. Fazit

**Die Elektrotechnik-Tools sind nun First-Class-Citizens in co-glitch:**

- ✅ **Native Installation** via `make install-eda` (idempotent, Arch/Ubuntu)
- ✅ **Git-ready Projekte** via `make eda-project` (KiCad & QElectroTech)
- ✅ **Automatisches Backup** via `make backup` (Git-Bundles + Working-Tree)
- ✅ **Keine Container-Overhead** — Desktop-Apps laufen nativ auf GPU/Client
- ✅ **Voll in Workflow integriert** — Forgejo (Git), n8n (Automation), OpenCode (AI-Assist)

**Der Client (Laptop) ist damit die komplette EDA-Workstation** — vom Schaltplan über PCB-Layout bis Simulation, alles versioniert, gebackupt, und via Tailnet/Forgejo synchronisierbar.

---

*Bericht generiert 2026-10-27 — basierend auf Live-Verifikation aller Makefile-Targets & Scripts.*
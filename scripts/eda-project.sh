#!/bin/bash
# Neues EDA-Projekt anlegen (KiCad oder QElectroTech)
# Usage: eda-project.sh <name> <kicad|qelectrotech>

set -euo pipefail

NAME="${1:-}"
TYPE="${2:-kicad}"

if [ -z "$NAME" ]; then
    echo "Usage: $0 <project-name> [kicad|qelectrotech]"
    exit 1
fi

PROJECT_DIR="${HOME}/projects/eda/${NAME}"
mkdir -p "$PROJECT_DIR"

case "$TYPE" in
    kicad)
        echo "Erstelle KiCad-Projekt: $NAME"
        if ! command -v kicad-cli &> /dev/null; then
            echo "FEHLER: kicad-cli nicht gefunden. KiCad installieren?"
            exit 1
        fi
        # Minimale KiCad-Projektstruktur manuell anlegen (kicad-cli hat kein 'project new')
        cat > "${PROJECT_DIR}/${NAME}.kicad_pro" << PROEOF
{
    "board": {
        "design_settings": {
            "defaults": {
                "board_outline_line_width": 0.15,
                "copper_line_width": 0.2,
                "copper_text_italic": false,
                "copper_text_size": 1.5,
                "copper_text_upright": false,
                "court-yard_line_width": 0.15,
                "dimension_precision": 4,
                "dimension_units": 3,
                "fab_line_width": 0.15,
                "fab_text_italic": false,
                "fab_text_size": 1.5,
                "fab_text_upright": false,
                "other_line_width": 0.15,
                "other_text_italic": false,
                "other_text_size": 1.5,
                "other_text_upright": false,
                "silk_line_width": 0.15,
                "silk_text_italic": false,
                "silk_text_size": 1.5,
                "silk_text_upright": false,
                "zone_45_only": false,
                "zone_fillet": 0.3,
                "zone_min_thickness": 0.15
            },
            "diff_pair_dimensions": [],
            "drc_exclusions": [],
            "rule_severities": {
                "annular_ring": "error",
                "clearance": "error",
                "copper_edge_clearance": "error",
                "courtyard_clearance": "error",
                "diff_pair_gap_out_of_range": "error",
                "diff_pair_uncoupled_length_too_long": "error",
                "drill_out_of_range": "error",
                "duplicate_footprints": "error",
                "edge_clearance": "error",
                "extra_footprint": "error",
                "footprint": "error",
                "footprint_courtyard_clearance": "error",
                "footprint_type": "error",
                "hole_clearance": "error",
                "hole_near_hole": "error",
                "invalid_outline": "error",
                "item_on_disabled_layer": "error",
                "items_not_allowed": "error",
                "length_out_of_range": "error",
                "malformed_courtyard": "error",
                "microvia_drill_out_of_range": "error",
                "missing_courtyard": "error",
                "missing_footprint": "error",
                "net_conflict": "error",
                "npth_inside_courtyard": "error",
                "padstack": "error",
                "pth_inside_courtyard": "error",
                "shorting_items": "error",
                "silk_over_copper": "warning",
                "silk_over_pad": "warning",
                "skew_out_of_range": "error",
                "through_hole_pad_without_hole": "error",
                "too_many_vias": "error",
                "track_width": "error",
                "unconnected_items": "error",
                "unconnected_pad": "error",
                "zone_has_no_area": "error"
            },
            "teardrops": {
                "scope": "none",
                "teardrop_max_length": 2.5,
                "teardrop_min_length": 0.5,
                "teardrop_min_width": 0.5,
                "teardrop_stroke": 0.5
            },
            "track_widths": [0.25, 0.5, 0.8],
            "via_dimensions": [
                {
                    "drill": 0.5,
                    "size": 0.8
                }
            ],
            "via_types": [
                "through"
            ],
            "zone_clearance": 0.508
        },
        "layer_presets": []
    },
    "cvpcb": {
        "equivalence_files": []
    },
    "eeschema": {
        "version": 20240108,
        "libraries": []
    },
    "meta": {
        "version": 1,
        "filename": "${NAME}.kicad_pro"
    },
    "net_settings": {
        "classes": {
            "Default": {
                "bus_width": 12,
                "clearance": 0.254,
                "diff_pair_gap": 0.25,
                "diff_pair_via_gap": 0.25,
                "diff_pair_width": 0.25,
                "line_style": 0,
                "pcb_color": "rgba(0, 0, 0, 0)",
                "schematic_color": "rgba(0, 0, 0, 0)",
                "track_width": 0.25,
                "via_drill": 0.5,
                "via_size": 0.8
            }
        },
        "net_colors": {}
    },
    "pcbnew": {
        "page_settings": {
            "size": "A4",
            "orientation": "landscape",
            "title_block": {
                "title": "",
                "date": "",
                "rev": "",
                "company": "",
                "comment1": "",
                "comment2": "",
                "comment3": "",
                "comment4": "",
                "comment5": "",
                "comment6": "",
                "comment7": "",
                "comment8": "",
                "comment9": ""
            }
        },
        "last_paths": {
            "netlist": "",
            "library": "",
            "library_3d": ""
        },
        "layer_visibility": {
            "F.Cu": true,
            "B.Cu": true,
            "F.Silkscreen": true,
            "B.Silkscreen": true,
            "F.Mask": true,
            "B.Mask": true,
            "F.Paste": true,
            "B.Paste": true,
            "Edge.Cuts": true,
            "Margin": true,
            "Dwgs.User": true,
            "Cmts.User": true,
            "Eco1.User": true,
            "Eco2.User": true,
            "F.Courtyard": false,
            "B.Courtyard": false,
            "F.Fab": false,
            "B.Fab": false,
            "Adhes": false,
            "Rescue": false
        }
    },
    "schematic": {
        "page_settings": {
            "size": "A4",
            "orientation": "landscape",
            "title_block": {
                "title": "",
                "date": "",
                "rev": "",
                "company": "",
                "comment1": "",
                "comment2": "",
                "comment3": "",
                "comment4": "",
                "comment5": "",
                "comment6": "",
                "comment7": "",
                "comment8": "",
                "comment9": ""
            }
        },
        "schematics": {
            "uuid": "00000000-0000-0000-0000-000000000000",
            "name": "Root",
            "type": "sheet",
            "file": "${NAME}.kicad_sch"
        }
    }
}
PROEOF

        # Leere Schematic-Datei
        cat > "${PROJECT_DIR}/${NAME}.kicad_sch" << SCHEOF
(kicad_sch (version 20240108) (generator "eeschema") (uuid "00000000-0000-0000-0000-000000000000") (paper "A4") (title_block (title "") (company "") (rev "") (date "") (source "") (comment "") (comment2 "") (comment3 "") (comment4 "") (comment5 "") (comment6 "") (comment7 "") (comment8 "") (comment9 "")))
SCHEOF

        # Leere PCB-Datei
        cat > "${PROJECT_DIR}/${NAME}.kicad_pcb" << PCBEOF
(kicad_pcb (version 20240108) (generator "pcbnew") (generator_version "10.0") (uuid "00000000-0000-0000-0000-000000000000") (paper "A4") (layers (0 "F.Cu" signal) (31 "B.Cu" signal) (32 "F.Silkscreen" user) (33 "B.Silkscreen" user) (34 "F.Mask" user) (35 "B.Mask" user) (36 "F.Paste" user) (37 "B.Paste" user) (38 "Edge.Cuts" user) (39 "Margin" user) (40 "Dwgs.User" user) (41 "Cmts.User" user) (42 "Eco1.User" user) (43 "Eco2.User" user) (44 "F.Courtyard" user) (45 "B.Courtyard" user) (46 "F.Fab" user) (47 "B.Fab" user) (48 "Adhes" user) (49 "Rescue" user)) (setup (stackup (1 (31 "B.Cu"))) (pad_drill_oval false) (trace_min 0.2) (via_drill_min 0.25) (via_size_min 0.5) (via_drill 0.5) (via_size 0.8) (drc_exclusions) (rule_severities) (zone_connection 0) (zone_clearance 0.508) (zone_fillet 0.3) (zone_min_thickness 0.15) (teardrops_scope none) (teardrops_stroke 0.5) (teardrops_min_width 0.5) (teardrops_max_length 2.5) (teardrops_min_length 0.5) (track_widths 0.25 0.5 0.8) (via_dimensions (0.8 0.5)) (via_types through) (net_classes (net_class "Default" (clearance 0.254) (track_width 0.25) (via_size 0.8) (via_drill 0.5) (diff_pair_gap 0.25) (diff_pair_width 0.25) (diff_pair_via_gap 0.25))))
PCBEOF

        cat > "${PROJECT_DIR}/.gitignore" << 'GITEOF'
# KiCad
*.bak
*.kicad_pro-bak
*.sch-bak
*.kicad_pcb-bak
*.kicad_sym-bak
*.kicad_dru-bak
*.kicad_sch-bak
fp-lib-table
sym-lib-table
*~
GITEOF
        ;;
    qelectrotech)
        echo "Erstelle QElectroTech-Projekt: $NAME"
        mkdir -p "${PROJECT_DIR}/elements" "${PROJECT_DIR}/projects" "${PROJECT_DIR}/titleblocks"
        cat > "${PROJECT_DIR}/${NAME}.qet" << 'QETEOF'
<?xml version="1.0" encoding="UTF-8"?>
<project version="0.100">
  <diagrams>
    <diagram name="Haupt" />
  </diagrams>
  <collections />
</project>
QETEOF
        cat > "${PROJECT_DIR}/.gitignore" << 'GITEOF'
# QElectroTech
*~
*.bak
GITEOF
        ;;
    *)
        echo "Unbekannter TYPE: $TYPE (erwartet: kicad|qelectrotech)"
        exit 1
        ;;
esac

echo "Git-Repo initialisieren..."
cd "$PROJECT_DIR" && git init && git add . && git commit -m "Initial $TYPE project: $NAME"

echo "✓ Projekt $NAME ($TYPE) erstellt in $PROJECT_DIR"
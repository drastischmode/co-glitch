#!/bin/bash
# Oracle Cloud Free Tier Keepalive
# Verhindert Abschaltung durch 25% CPU Duty Cycle
# Läuft: 15min CPU-Last, 45min Pause
# Loggt zu stdout (systemd journal) und optional zu Datei

set -euo pipefail

# Konfiguration via Environment (mit Defaults)
DUTY_CYCLE_ON_SECONDS=${KEEPALIVE_ON:-900}      # 15 Minuten
DUTY_CYCLE_OFF_SECONDS=${KEEPALIVE_OFF:-2700}   # 45 Minuten
CPU_WORKERS=${KEEPALIVE_WORKERS:-1}             # ~25% auf 4 vCPU
LOG_FILE=${KEEPALIVE_LOG_FILE:-/var/log/keepalive.log}

# Log-Funktion
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    # Auch in Datei loggen (falls schreibbar)
    if [ -w "$(dirname "$LOG_FILE")" ] 2>/dev/null || [ ! -e "$LOG_FILE" ] 2>/dev/null; then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Cleanup bei Signal
cleanup() {
    log "Keepalive beendet (Signal empfangen)"
    exit 0
}
trap cleanup SIGTERM SIGINT

log "=== Keepalive Service gestartet ==="
log "Konfiguration: ON=${DUTY_CYCLE_ON_SECONDS}s, OFF=${DUTY_CYCLE_OFF_SECONDS}s, Workers=${CPU_WORKERS}"

# Prüfen ob stress-ng verfügbar
HAS_STRESS_NG=false
if command -v stress-ng &> /dev/null; then
    HAS_STRESS_NG=true
    log "stress-ng gefunden: $(stress-ng --version 2>&1 | head -1)"
else
    log "WARNUNG: stress-ng nicht installiert, nutze Fallback (busy loop)"
fi

while true; do
    log "Starte CPU-Lastphase (${DUTY_CYCLE_ON_SECONDS}s, ${CPU_WORKERS} Worker)..."
    
    if [ "$HAS_STRESS_NG" = true ]; then
        # stress-ng mit Timeout und Workers
        # --cpu N startet N Worker, --timeout beendet nach Sekunden
        # --metrics-brief zeigt Stats am Ende
        stress-ng --cpu "$CPU_WORKERS" --timeout "${DUTY_CYCLE_ON_SECONDS}s" --metrics-brief 2>&1 | while IFS= read -r line; do
            log "stress-ng: $line"
        done
        STRESS_EXIT=${PIPESTATUS[0]}
        if [ $STRESS_EXIT -ne 0 ]; then
            log "WARNUNG: stress-ng beendet mit Exit Code $STRESS_EXIT"
        fi
    else
        # Fallback: busy loop in Subshell mit timeout
        # timeout sendet SIGTERM nach Ablauf, das wir abfangen
        timeout "${DUTY_CYCLE_ON_SECONDS}s" bash -c "
            while true; do
                :  # No-op
            done
        " 2>&1 | while IFS= read -r line; do
            log "fallback: $line"
        done
        TIMEOUT_EXIT=${PIPESTATUS[0]}
        if [ $TIMEOUT_EXIT -eq 124 ]; then
            log "Fallback: Timeout erreicht (erwartet)"
        elif [ $TIMEOUT_EXIT -ne 0 ]; then
            log "WARNUNG: Fallback beendet mit Exit Code $TIMEOUT_EXIT"
        fi
    fi
    
    log "CPU-Lastphase beendet. Pause ${DUTY_CYCLE_OFF_SECONDS}s..."
    
    # Sleep in kleinen Schritten für schnelleres Signal-Handling
    SLEEP_REMAINING=$DUTY_CYCLE_OFF_SECONDS
    while [ $SLEEP_REMAINING -gt 0 ]; do
        SLEEP_CHUNK=60
        if [ $SLEEP_REMAINING -lt $SLEEP_CHUNK ]; then
            SLEEP_CHUNK=$SLEEP_REMAINING
        fi
        sleep $SLEEP_CHUNK
        SLEEP_REMAINING=$((SLEEP_REMAINING - SLEEP_CHUNK))
    done
done
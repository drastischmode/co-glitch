#!/bin/bash
# Generiert sichere Secrets für co-glitch
# Nutzt openssl für kryptografisch sichere Zufallswerte

set -euo pipefail

ENV_FILE=".env"
EXAMPLE_FILE=".env.example"

# Prüfen ob openssl verfügbar ist
if ! command -v openssl &> /dev/null; then
    echo "FEHLER: openssl nicht gefunden. Bitte installieren (apt install openssl / pacman -S openssl)"
    exit 1
fi

# Prüfen ob .env.example existiert
if [ ! -f "$EXAMPLE_FILE" ]; then
    echo "FEHLER: $EXAMPLE_FILE nicht gefunden. Bist du im co-glitch Root-Verzeichnis?"
    exit 1
fi

# Wenn .env existiert: Backup anbieten
if [ -f "$ENV_FILE" ]; then
    echo "WARNUNG: $ENV_FILE existiert bereits."
    if [ ! -t 0 ]; then
        echo "Nicht-interaktiv (kein TTY) -> Abbruch ohne Änderung."
        echo "Bestehende .env bleibt unverändert. Manuell: rm .env && make gen-secrets"
        exit 0
    fi
    read -rp "Backup erstellen und neu generieren? [j/N] " -n 1 || true
    echo
    if [[ ! ${REPLY:-} =~ ^[Jj]$ ]]; then
        echo "Abbruch. Bestehende .env bleibt unverändert."
        exit 0
    fi
    BACKUP_FILE=".env.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$ENV_FILE" "$BACKUP_FILE"
    echo "Backup erstellt: $BACKUP_FILE"
fi

cp "$EXAMPLE_FILE" "$ENV_FILE"

# Funktion zur Generierung von Hex-Secrets (32 Bytes = 64 Hex-Zeichen)
generate_hex() {
    openssl rand -hex 32
}

# Funktion zur Generierung von Base64-Secrets (32 Bytes = 44 Base64-Zeichen, URL-safe)
generate_b64() {
    openssl rand -base64 32 | tr '+/' '-_' | tr -d '='
}

echo "Generiere sichere Passwörter und Keys..."

# Datenbank-Passwörter (Hex) - nur Client-Secrets
sed -i "s|GENERATE_ME_SUPABASE_PASS|$(generate_hex)|g" "$ENV_FILE"
sed -i "s|GENERATE_ME_POSTIZ_JWT|$(generate_hex)|g" "$ENV_FILE"
sed -i "s|GENERATE_ME_FORGEJO_PASS|$(generate_hex)|g" "$ENV_FILE"
# Redis Passwort für Postiz (Extended)
sed -i "s|GENERATE_ME_REDIS_PASS|$(generate_hex)|g" "$ENV_FILE"
# BESZEL_AGENT_KEY wird NICHT generiert: das ist der Public Key, den der Beszel-Hub
# beim Anlegen eines Systems ausgibt (Settings -> Systeme -> Hinzufuegen).
# Ein Zufallswert hier fuehrt zu "ssh: no key found" im Agent (Crash-Loop).
if grep -q '^BESZEL_AGENT_KEY=""' "$ENV_FILE"; then
    echo "HINWEIS: BESZEL_AGENT_KEY bleibt leer (Public Key aus dem Beszel-Hub eintragen)."
    echo "          Ohne Key laeuft der Agent nicht; er ist daher im Profil 'client-extended'."
fi

# OPENCODE_API_KEY Default setzen falls "public"
if grep -q '^OPENCODE_API_KEY="public"' "$ENV_FILE"; then
    echo "OPENCODE_API_KEY auf Default 'public' belassen."
fi

# SUPABASE_DB_URL zusammenbauen (nachdem Passwort generiert wurde)
SUPABASE_PASS=$(grep '^SUPABASE_DB_PASS=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
if [ -n "$SUPABASE_PASS" ] && [ "$SUPABASE_PASS" != "GENERATE_ME_SUPABASE_PASS" ]; then
    # URL-encode das Passwort für safety
    ENCODED_PASS=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$SUPABASE_PASS" 2>/dev/null || echo "$SUPABASE_PASS")
    sed -i "s|^SUPABASE_DB_URL=.*|SUPABASE_DB_URL=\"postgresql://postgres:${ENCODED_PASS}@supabase-db:5432/postgres\"|" "$ENV_FILE"
fi

echo ""
echo "✅ Secrets generiert in $ENV_FILE"
echo ""
echo "⚠️  Nächste Schritte:"
echo "   1. Trage deine API-Keys ein: NVIDIA_API_KEY, ZAI_API_KEY"
echo "      (OPENCODE_API_KEY='public' funktioniert oft ohne Key)"
echo "   2. Für VPS (optional): Caddy Hash generieren:"
echo "      caddy hash-password --plaintext 'dein-passwort'  -> CADDY_ADMIN_HASH"
echo ""
echo "Dann: make client-setup"
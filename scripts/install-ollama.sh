#!/bin/bash
# Installiert Ollama und lädt lokale Modelle für OpenCode-Fallback
# OpenCode benötigt mindestens 64k Kontext – qwen3.5:8b erfüllt das.

set -euo pipefail

echo "=== Installiere Ollama (lokaler KI-Fallback) ==="

if command -v ollama &> /dev/null; then
    echo "Ollama ist bereits installiert."
else
    curl -fsSL https://ollama.com/install.sh | sh
fi

echo "Lade lokale Modelle herunter..."
# OpenCode benötigt mindestens 64k Kontext – qwen3.5 erfüllt das.
ollama pull qwen3.5:8b

echo "=== Ollama-Setup abgeschlossen ==="
echo "Lokales Modell 'qwen3.5:8b' ist unter http://localhost:11434/v1 erreichbar."
echo "Kontextfenster: qwen3.5 bietet ausreichend Kapazität für OpenCode (>= 64k)."
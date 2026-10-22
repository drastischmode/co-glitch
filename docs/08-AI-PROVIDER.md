# AI Provider Strategie

## Übersicht

co-glitch nutzt eine **4-Provider-Fallback-Kette** für maximale Verfügbarkeit und Kostenkontrolle:

```
Primär: OpenCode Zen (Free Tier)
  ↓ Fallback 1
NVIDIA NIM (Nemotron 3.5 Lightning)
  ↓ Fallback 2
NVIDIA NIM (Nemotron 3 Nano Omni - Multimodal + Reasoning)
  ↓ Fallback 3
z.ai / Zhipu (GLM-4.5 Flash)
  ↓ Fallback 4 (Letzter)
Ollama Lokal (qwen3.5:8b - 100% Offline)
```

## Provider-Details

### 1. OpenCode Zen (Primär)

| Eigenschaft | Wert |
|-------------|------|
| **Base URL** | `https://opencode.ai/zen/v1` |
| **Auth** | `OPENCODE_API_KEY` (Default: `"public"`) |
| **Kosten** | Kostenlos |
| **Rate Limit** | Höher mit Key, anonym nutzbar |
| **Modelle** | 7 Free Models (siehe unten) |

**Verfügbare Modelle (7 Free):**
| Model ID | Name | Stärke |
|----------|------|--------|
| `deepseek-v4-flash-free` | DeepSeek V4 Flash | Stärkster Allrounder (Coding, Reasoning, Tool Calls) |
| `big-pickle` | Big Pickle | S+ Tier, 200k Kontext, exzellent für Agenten |
| `mimo-v2.5-free` | MiMo V2.5 | Balanced Performance |
| `qwen3.6-plus-free` | Qwen 3.6 Plus | Starke Multilingual |
| `minimax-m3-free` | MiniMax M3 | Große Kontext-Fenster |
| `nemotron-3-ultra-free` | Nemotron 3 Ultra | NVIDIA's Flaggschiff (Free Tier) |
| `north-mini-code-free` | North Mini Code | Code-spezifisch optimiert |

### 2. NVIDIA NIM (Fallback 1-2)

| Eigenschaft | Wert |
|-------------|------|
| **Base URL** | `https://integrate.api.nvidia.com/v1` |
| **Auth** | `NVIDIA_API_KEY` (erforderlich) |
| **Kosten** | Kostenlos (Free Tier) |
| **Rate Limit** | 40 RPM (Requests per Minute) |
| **Anmeldung** | https://build.nvidia.com/ |

**Verfügbare Modelle:**
| Model ID | Name | Besonderheit |
|----------|------|--------------|
| `nvidia/nemotron-3.5-lightning-30b-a3b` | Nemotron 3.5 Lightning | Schnelles 30B MoE Modell |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | Nemotron 3 Nano Omni | **Multimodal** (Bild/Video/Audio/Text) + Reasoning + Tool Calling |
| `nvidia/nemotron-3-ultra-550b-a55b` | Nemotron 3 Ultra 550B | Größtes Modell, Reserve |

### 3. z.ai / Zhipu (Fallback 3)

| Eigenschaft | Wert |
|-------------|------|
| **Base URL** | `https://api.z.ai/api/paas/v4` |
| **Auth** | `ZAI_API_KEY` (erforderlich) |
| **Kosten** | Kostenlos (Flash Modelle) |
| **Rate Limit** | ~1 req/s, ~1.000 Requests/Tag |
| **Anmeldung** | https://z.ai/ |

**Verfügbare Modelle:**
| Model ID | Name | Besonderheit |
|----------|------|--------------|
| `glm-4.5-flash` | GLM-4.5 Flash | Starkes Coding-Modell, OpenAI-kompatibel |
| `glm-4.7-flash` | GLM-4.7 Flash | Neuere Version, Reserve |

> **Wichtig**: z.ai ist der **letzte Cloud-Fallback** vor Ollama aufgrund strikter Rate-Limits (~1.000/Tag). Nicht für High-Volume geeignet.

### 4. Ollama Lokal (Letzter Fallback)

| Eigenschaft | Wert |
|-------------|------|
| **Base URL** | `http://localhost:11434/v1` (via `@ai-sdk/openai-compatible`) |
| **Auth** | Keine (lokal) |
| **Kosten** | Kostenlos, Offline |
| **Hardware** | CPU (RAM: 8-16 GB empfohlen) |
| **Installation** | `make install-ollama` |

**Verfügbares Modell:**
| Model ID | Name | Kontext | RAM |
|----------|------|---------|-----|
| `qwen3.5:8b` | Qwen 3.5 8B | **64k+** Token | ~6-8 GB |

> **Wichtig**: OpenCode benötigt **mindestens 64k Kontext-Fenster**. Kleinere Modelle wie `llama3.2:3b` (oft nur 8k) funktionieren **nicht** zuverlässig.

## Fallback-Kette (config/opencode/fallback.json)

```json
{
  "enabled": true,
  "defaultFallback": [
    "opencode/big-pickle",
    "nvidia/nvidia/nemotron-3.5-lightning-30b-a3b",
    "nvidia/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
    "zai/glm-4.5-flash",
    "ollama/qwen3.5:8b"
  ],
  "cooldownMs": 60000,
  "maxRetries": 2,
  "logging": false
}
```

**Logik:**
1. Primär: `opencode/deepseek-v4-flash-free` (stärkstes Free-Modell, SWE-bench ~79%)
2. Fallback 1: `opencode/big-pickle` (bleibt im Zen-Ökosystem, 200k Kontext)
3. Fallback 2: `nvidia/nemotron-3.5-lightning-30b-a3b` (schnelles 30B MoE, 40 RPM)
4. Fallback 3: `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` (Multimodal + Reasoning, 40 RPM)
5. Fallback 4: `zai/glm-4.5-flash` (starkes Coding, ~1.000/Tag)
5. Letzter Fallback: `ollama/qwen3.5:8b` (100% offline, 64k+ Kontext)

## Konfiguration

### .env
```bash
# OpenCode Zen (Default "public" funktioniert oft ohne Key)
OPENCODE_API_KEY="public"

# NVIDIA NIM (Account auf build.nvidia.com)
NVIDIA_API_KEY=""

# z.ai / Zhipu (Account auf z.ai)
ZAI_API_KEY=""

# Ollama (lokal, optional)
OLLAMA_HOST="http://localhost:11434"
```

### OpenCode Config (config/opencode/opencode.json)
```json
{
  "provider": {
    "opencode": { "baseURL": "https://opencode.ai/zen/v1", "apiKey": "{env:OPENCODE_API_KEY}" },
    "nvidia": { "baseURL": "https://integrate.api.nvidia.com/v1", "apiKey": "{env:NVIDIA_API_KEY}" },
    "zai": { "baseURL": "https://api.z.ai/api/paas/v4", "apiKey": "{env:ZAI_API_KEY}" },
    "ollama": { "npm": "@ai-sdk/openai-compatible", "options": { "baseURL": "{env:OLLAMA_HOST}" } }
  },
  "model": "opencode/deepseek-v4-flash-free",
  "small_model": "opencode/big-pickle"
}
```

## Validierung

```bash
# Alle Endpunkte prüfen
make validate-models

# Ausgabe:
# 1. OpenCode Zen (Free Tier)...
#    ✓ HTTP 200
# 2. NVIDIA NIM...
#    ✓ HTTP 200 (oder SKIP wenn Key fehlt)
# 3. z.ai / Zhipu...
#    ✓ HTTP 200 (oder SKIP wenn Key fehlt)
# 4. Ollama (lokal)...
#    ✓ HTTP 200 (oder HINT: make install-ollama)
```

## Ollama Installation

```bash
# Einmalig installieren
make install-ollama

# Manuell:
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen3.5:8b

# Prüfen
curl http://localhost:11434/v1/models
```

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| OpenCode Zen 429 | Fallback greift automatisch, Key setzen für höhere Limits |
| NVIDIA 401/403 | API-Key in `.env` prüfen (`NVIDIA_API_KEY`), Account auf build.nvidia.com |
| z.ai 429 | Rate Limit erreicht (~1.000/Tag), Fallback auf Ollama |
| Ollama "model not found" | `ollama pull qwen3.5:8b` ausführen |
| Ollama OOM | Mehr RAM, oder `OLLAMA_NUM_PARALLEL=1` setzen |
| Fallback greift nicht | `make validate-models` prüfen, `fallback.json` validieren |

## Kosten-Übersicht

| Provider | Monatliche Kosten | Limit |
|----------|-------------------|-------|
| OpenCode Zen | 0 € | Unbegrenzt (mit Key höher) |
| NVIDIA NIM | 0 € | 40 RPM |
| z.ai | 0 € | ~1.000 Requests/Tag |
| Ollama | 0 € | Hardware (Strom) |

**Gesamt**: **0 €** für volle Funktionalität

## Best Practices

1. **Primär-Modell nicht ändern** - `deepseek-v4-flash-free` ist am stärksten
2. **API-Keys setzen** - Erhöht Limits bei Zen und NVIDIA
3. **Ollama installieren** - Garantiert Offline-Fallback
4. **Rate-Limits respektieren** - Nicht manuell Fallback triggern
5. **Monitoring** - `make validate-models` in Cron (täglich)
6. **Model-Updates** - Renovate prüft Docker Images, Provider-Updates manuell tracken
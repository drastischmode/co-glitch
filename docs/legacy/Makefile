.PHONY: help gen-secrets validate-env vps-setup client-setup up-core up-monitoring up-voice up-proxy down-all health-check logs-core logs-monitoring logs-voice logs-proxy status clean-volumes kong-init install-ollama validate-models

# Standardziel
.DEFAULT_GOAL := help

help:
	@echo "co-glitch - Infrastructure as Code"
	@echo "---------------------------------"
	@echo ""
	@echo "Setup & Secrets:"
	@echo "  make gen-secrets       : Generiert .env mit sicheren Passwörtern"
	@echo "  make validate-env      : Prüft .env auf Vollständigkeit"
	@echo ""
	@echo "Bootstrap:"
	@echo "  make vps-setup         : Richtet VPS ein (Docker, UFW, Tailscale, Keepalive)"
	@echo "  make client-setup      : Richtet Client ein (Docker, Tools, Tailscale)"
	@echo "  make install-ollama    : Installiert Ollama + qwen3.5:8b (lokaler KI-Fallback)"
	@echo ""
	@echo "Stacks starten/stoppen:"
	@echo "  make up-core           : Startet Core-Stack (n8n, Postiz, Forgejo, Supabase, Temporal)"
	@echo "  make up-monitoring     : Startet Monitoring-Stack (Kuma, Beszel, Dozzle, cAdvisor, Diun)"
	@echo "  make up-voice          : Startet Voice-Stack (Whisper)"
	@echo "  make up-proxy          : Startet Caddy Reverse Proxy (Ports 8443-8447)"
	@echo "  make up-all            : Startet alle Stacks (inkl. Proxy)"
	@echo "  make down-all          : Stoppt alle Container (behält Volumes)"
	@echo "  make clean-volumes     : Stoppt alle Container UND löscht Volumes (VORSICHT!)"
	@echo ""
	@echo "Logs & Status:"
	@echo "  make logs-core         : Zeigt Core-Stack Logs (follow)"
	@echo "  make logs-monitoring   : Zeigt Monitoring-Stack Logs (follow)"
	@echo "  make logs-voice        : Zeigt Voice-Stack Logs (follow)"
	@echo "  make logs-proxy        : Zeigt Caddy Proxy Logs (follow)"
	@echo "  make status            : Zeigt Status aller Container"
	@echo ""
	@echo "Health & Wartung:"
	@echo "  make health-check      : Führt System-Check durch (Container, UFW, Caddy Ports, DNS, Disk, RAM)"
	@echo "  make kong-init         : Initialisiert Kong Consumers für Supabase"
	@echo "  make validate-models   : Prüft Erreichbarkeit aller konfigurierten KI-Modelle"

gen-secrets:
	@bash scripts/generate-secrets.sh

validate-env:
	@bash scripts/validate-env.sh

vps-setup:
	@bash scripts/vps-bootstrap.sh

client-setup:
	@bash scripts/client-bootstrap.sh

install-ollama:
	@bash scripts/install-ollama.sh

validate-models:
	@echo "=== Prüfe KI-Modell-Endpunkte ==="
	@echo ""
	@echo "1. OpenCode Zen (Free Tier)..."
	@curl -s -o /dev/null -w "   HTTP: %{http_code}  (Erwartet: 200)\n" https://opencode.ai/zen/v1/models || echo "   FEHLER: Nicht erreichbar"
	@echo ""
	@echo "2. NVIDIA NIM (API-Key erforderlich)..."
	@if [ -n "$$NVIDIA_API_KEY" ]; then \
		curl -s -o /dev/null -w "   HTTP: %{http_code}  (Erwartet: 200)\n" \
			-H "Authorization: Bearer $$NVIDIA_API_KEY" \
			https://integrate.api.nvidia.com/v1/models; \
	else echo "   NVIDIA_API_KEY nicht gesetzt – überspringe."; fi
	@echo ""
	@echo "3. z.ai / Zhipu (API-Key erforderlich)..."
	@if [ -n "$$ZAI_API_KEY" ]; then \
		curl -s -o /dev/null -w "   HTTP: %{http_code}  (Erwartet: 200)\n" \
			-H "Authorization: Bearer $$ZAI_API_KEY" \
			https://api.z.ai/api/paas/v4/models; \
	else echo "   ZAI_API_KEY nicht gesetzt – überspringe."; fi
	@echo ""
	@echo "4. Ollama (lokal)..."
	@curl -s -o /dev/null -w "   HTTP: %{http_code}  (Erwartet: 200)\n" http://localhost:11434/v1/models 2>/dev/null || echo "   Ollama nicht erreichbar (make install-ollama ausführen?)"
	@echo ""
	@echo "=== Modell-Validierung abgeschlossen ==="

up-core:
	@docker compose -f docker/core/docker-compose.yml --profile core up -d

up-monitoring:
	@docker compose -f docker/monitoring/docker-compose.yml --profile monitoring up -d

up-voice:
	@docker compose -f docker/voice/docker-compose.yml --profile voice up -d

up-proxy:
	@docker compose -f docker/caddy/docker-compose.yml --profile proxy up -d

up-all: up-core up-monitoring up-voice up-proxy

down-all:
	@docker compose -f docker/core/docker-compose.yml down
	@docker compose -f docker/monitoring/docker-compose.yml down
	@docker compose -f docker/voice/docker-compose.yml down
	@docker compose -f docker/caddy/docker-compose.yml down

clean-volumes:
	@echo "⚠️  WARNUNG: Dies löscht ALLE Daten in Docker Volumes!"
	@read -rp "Wirklich alle Volumes löschen? [j/N] " -n 1; echo; \
	if [[ $$REPLY =~ ^[Jj]$$ ]]; then \
		docker compose -f docker/core/docker-compose.yml down -v; \
		docker compose -f docker/monitoring/docker-compose.yml down -v; \
		docker compose -f docker/voice/docker-compose.yml down -v; \
		docker compose -f docker/caddy/docker-compose.yml down -v; \
		echo "Volumes gelöscht."; \
	else \
		echo "Abgebrochen."; \
	fi

logs-core:
	@docker compose -f docker/core/docker-compose.yml logs -f --tail=100

logs-monitoring:
	@docker compose -f docker/monitoring/docker-compose.yml logs -f --tail=100

logs-voice:
	@docker compose -f docker/voice/docker-compose.yml logs -f --tail=100

logs-proxy:
	@docker compose -f docker/caddy/docker-compose.yml logs -f --tail=100

status:
	@echo "=== Container Status ==="
	@docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
	@echo ""
	@echo "=== Docker System ==="
	@docker system df

health-check:
	@bash scripts/health-check.sh

kong-init:
	@echo "Initialisiere Kong für Supabase..."
	@docker compose -f docker/core/docker-compose.yml exec -T kong /scripts/supabase-kong-init.sh
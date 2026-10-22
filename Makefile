.PHONY: help gen-secrets client-setup client-health install-ollama validate-models doctor \
        up-client up-voice down-client up-all down-all \
        up-client-extended down-client-extended \
        vps-setup vps-health up-vps down-vps \
        backup restore update uninstall

# Compose-Aufrufe laden .env explizit aus dem Repo-Root.
# Ohne --env-file sucht Compose die .env im Verzeichnis der Compose-Datei
# (docker/client/) und alle Secrets bleiben leer.
ENVFILE := $(if $(wildcard .env),--env-file .env,)
COMPOSE_CLIENT := docker compose $(ENVFILE) -f docker/client/docker-compose.yml
COMPOSE_VOICE  := docker compose $(ENVFILE) -f docker/voice/docker-compose.yml
COMPOSE_VPS    := docker compose $(ENVFILE) -f docker/vps/docker-compose.yml

help:
	@echo "co-glitch - Client-First IaC"
	@echo "=================================="
	@echo "CLIENT (primär):"
	@echo "  make gen-secrets      .env mit sicheren Passwörtern erzeugen"
	@echo "  make client-setup     Linux-Client einrichten (Arch/Ubuntu)"
	@echo "  make install-ollama   Lokale Modelle (qwen3.5:8b)"
	@echo "  make validate-models  AI-Endpunkte prüfen"
	@echo "  make doctor           Vollständiger System-Check (Health + Models + Config)"
	@echo "  make up-client        Client-Stack starten (Default-Profil)"
	@echo "  make up-client-extended  Extended-Stack (Postiz, Beszel-Agent, Diun)"
	@echo "  make up-voice         Voice-Stack starten (Whisper)"
	@echo "  make client-health    Client-Health-Check"
	@echo "  make down-client      Client-Stack stoppen"
	@echo "  make down-client-extended  Extended-Stack stoppen"
	@echo "  make down-voice       Voice-Stack stoppen"
	@echo "  make backup           Backup erstellen (DB + Volumes)"
	@echo "  make restore DATE=... Restore aus Backup (Format: YYYY-MM-DD)"
	@echo "  make update           Stack aktualisieren (Git pull + Image pull + Rolling restart)"
	@echo "  make uninstall        Stack deinstallieren (Container stoppen, --purge für Volumes)"
	@echo ""
	@echo "VPS (optional):"
	@echo "  make vps-setup        VPS einrichten (Ubuntu)"
	@echo "  make up-vps           VPS-Stack starten"
	@echo "  make vps-health       VPS-Health-Check"
	@echo "  make down-vps         VPS-Stack stoppen"

# ---------- CLIENT ----------
gen-secrets:
	@bash scripts/generate-secrets.sh

client-setup:
	@bash scripts/client-bootstrap.sh

install-ollama:
	@bash scripts/install-ollama.sh

validate-models:
	@bash scripts/validate-models.sh

doctor: validate-models client-health
	@$(COMPOSE_CLIENT) config --quiet && echo "✓ Docker Compose Config valid"
	@$(COMPOSE_VOICE) config --quiet && echo "✓ Voice Compose Config valid"
	@$(COMPOSE_VPS) config --quiet && echo "✓ VPS Compose Config valid"

up-client:
	@$(COMPOSE_CLIENT) --profile client up -d

up-client-extended:
	@$(COMPOSE_CLIENT) --profile client --profile client-extended up -d

up-voice:
	@$(COMPOSE_VOICE) --profile voice up -d

down-client:
	@$(COMPOSE_CLIENT) down
	@$(COMPOSE_VOICE) down

down-client-extended:
	@$(COMPOSE_CLIENT) --profile client --profile client-extended down

down-voice:
	@$(COMPOSE_VOICE) --profile voice down

client-health:
	@bash scripts/client-health-check.sh

# ---------- BACKUP / RESTORE / UPDATE ----------
backup:
	@bash scripts/backup.sh

restore:
	@if [ -z "$(DATE)" ]; then echo "Usage: make restore DATE=YYYY-MM-DD"; exit 1; fi
	@bash scripts/restore.sh $(DATE)

update:
	@bash scripts/update.sh

uninstall:
	@bash scripts/uninstall.sh

# ---------- VPS (OPTIONAL) ----------
vps-setup:
	@bash scripts/vps-bootstrap.sh

up-vps:
	@$(COMPOSE_VPS) --profile vps up -d

down-vps:
	@$(COMPOSE_VPS) down

vps-health:
	@bash scripts/vps-health-check.sh

# ---------- KOMBI ----------
up-all: up-client up-client-extended up-voice
down-all: down-client down-client-extended down-voice down-vps
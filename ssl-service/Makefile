# =============================================================================
# SSL SERVICE — IaC Makefile
# Manages the running container. Does NOT build images.
# To build & push a new image: cd ~/workspace/applications/ssl-service && make build-push
# =============================================================================

.PHONY: help pull up down restart logs health status

COMPOSE := docker compose
SERVICE  := ssl-service

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
RED    := \033[0;31m
NC     := \033[0m

.DEFAULT_GOAL := help

help:
	@echo ""
	@echo "$(BLUE)ssl-service deployment targets$(NC)"
	@echo ""
	@echo "  $(GREEN)make pull$(NC)      Pull latest image from registry"
	@echo "  $(GREEN)make up$(NC)        Start the service"
	@echo "  $(GREEN)make down$(NC)      Stop and remove the container"
	@echo "  $(GREEN)make restart$(NC)   Restart the container"
	@echo "  $(GREEN)make logs$(NC)      Follow logs"
	@echo "  $(GREEN)make health$(NC)    Run health check"
	@echo "  $(GREEN)make status$(NC)    Show container status"
	@echo ""
	@echo "  IMAGE_TAG defaults to 'latest'. Override: make up IMAGE_TAG=1.0.0-abc1234"
	@echo ""

# Pull image before starting (ensures we have the requested tag)
pull:
	@echo "$(BLUE)Pulling image...$(NC)"
	$(COMPOSE) pull

# Validate .env exists, then bring up
up:
	@if [ ! -f .env ]; then \
		echo "$(RED)ERROR: .env not found.$(NC)"; \
		echo "       Run: cp .env.example .env  then fill in the values."; \
		exit 1; \
	fi
	$(COMPOSE) up -d
	@echo "$(GREEN)✓ ssl-service started$(NC)"
	@echo "  Health: make health"
	@echo "  Logs:   make logs"

down:
	@echo "$(YELLOW)Stopping ssl-service...$(NC)"
	$(COMPOSE) down

restart:
	$(COMPOSE) restart $(SERVICE)

logs:
	$(COMPOSE) logs -f $(SERVICE)

# Health check against the internal port (only reachable from this host or proxy-network)
health:
	@echo "$(BLUE)Checking ssl-service health...$(NC)"
	@docker exec $$($(COMPOSE) ps -q $(SERVICE)) \
		node -e "require('http').get('http://localhost:8888/health', (r) => { \
			let d=''; r.on('data',c=>d+=c); r.on('end',()=>{ \
				console.log(d); process.exit(r.statusCode===200?0:1); \
			}); \
		}).on('error',e=>{ console.error(e.message); process.exit(1); })" \
		&& echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Unhealthy$(NC)"

status:
	$(COMPOSE) ps

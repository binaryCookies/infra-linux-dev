# =============================================================================
# GLOBAL INFRASTRUCTURE MAKEFILE
# Dev server orchestration — pull-only (images built in app repos)
#
# Quick start:
#   make init          # Create Docker networks (run once)
#   make status        # Show all running containers
#   make deploy-all    # Bring up all managed services
#   make down-all      # Stop all managed services
# =============================================================================

.PHONY: help init status deploy-all down-all
.PHONY: ssl-up ssl-down ssl-status
.PHONY: proxy-up proxy-down proxy-restart proxy-status
.PHONY: diagnose chatbot-check recover-chatbot

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m

.DEFAULT_GOAL := help

# Paths (server layout)
SSL_DIR   := ssl-service
PROXY_DIR := reverse-proxy
INIT_NETWORKS_SCRIPT := scripts/init-networks.sh

# =============================================================================
# HELP
# =============================================================================
help:
	@echo ""
	@echo "$(BLUE)Infrastructure Management$(NC)"
	@echo ""
	@echo "  $(GREEN)make init$(NC)          Create required Docker networks (idempotent)"
	@echo "  $(GREEN)make status$(NC)        Show all running containers"
	@echo "  $(GREEN)make deploy-all$(NC)    Bring up all managed services (ordered)"
	@echo "  $(GREEN)make down-all$(NC)      Stop all managed services"
	@echo ""
	@echo "  $(GREEN)make ssl-up$(NC)        Start ssl-service"
	@echo "  $(GREEN)make proxy-up$(NC)      Start reverse-proxy nginx"
	@echo "  $(GREEN)make diagnose$(NC)      Snapshot runtime + timer + port state"
	@echo "  $(GREEN)make chatbot-check$(NC) Verify chatbot login path (8181/8090/8091)"
	@echo "                               Requires CHATBOT_TEST_EMAIL + CHATBOT_TEST_PASSWORD"
	@echo "  $(GREEN)make recover-chatbot$(NC) Ordered recovery: init -> ssl -> proxy -> checks"
	@echo ""
	@echo "  Per-service:  cd <service>/ && make help"
	@echo ""
	@echo "  Services managed here:  ssl-service, erpnext (external ref)"
	@echo "  Live apps (remote):     chatbot-api, sourri-api, reverse-proxy"
	@echo ""

# =============================================================================
# INIT — run once after cloning or on a fresh server
# =============================================================================
init:
	@echo "$(GREEN)Initializing Docker networks...$(NC)"
	@chmod +x $(INIT_NETWORKS_SCRIPT) && bash $(INIT_NETWORKS_SCRIPT)

# =============================================================================
# STATUS — server-wide container overview
# =============================================================================
status:
	@echo "$(BLUE)=== Running Containers ===$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

# =============================================================================
# DEPLOY — ordered startup (add services here as they are migrated)
# =============================================================================
deploy-all:
	@echo "$(GREEN)Deploying all managed services...$(NC)"
	$(MAKE) ssl-up
	$(MAKE) proxy-up

# =============================================================================
# DOWN — ordered shutdown (reverse of deploy)
# =============================================================================
down-all:
	@echo "$(YELLOW)Stopping all managed services...$(NC)"
	$(MAKE) proxy-down
	$(MAKE) ssl-down

# =============================================================================
# SSL SERVICE SHORTCUTS
# =============================================================================
ssl-up:
	$(MAKE) -C $(SSL_DIR) up

ssl-down:
	$(MAKE) -C $(SSL_DIR) down

ssl-status:
	$(MAKE) -C $(SSL_DIR) status

# =============================================================================
# REVERSE PROXY SHORTCUTS
# =============================================================================
proxy-up:
	@echo "$(GREEN)Starting reverse-proxy...$(NC)"
	@cd $(PROXY_DIR) && docker compose up -d

proxy-down:
	@echo "$(YELLOW)Stopping reverse-proxy...$(NC)"
	@cd $(PROXY_DIR) && docker compose down

proxy-restart:
	@echo "$(BLUE)Restarting reverse-proxy...$(NC)"
	@cd $(PROXY_DIR) && docker compose restart

proxy-status:
	@cd $(PROXY_DIR) && docker compose ps

# =============================================================================
# DIAGNOSTICS / RECOVERY
# =============================================================================
diagnose:
	@echo "$(BLUE)=== Containers ===$(NC)"
	@docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "$(BLUE)=== Failed Services ===$(NC)"
	@systemctl list-units --type=service --state=failed || true
	@echo ""
	@echo "$(BLUE)=== certbot.timer ===$(NC)"
	@systemctl status certbot.timer --no-pager -n 20 || true
	@echo ""
	@echo "$(BLUE)=== Listening Ports (80/443/8090/8091/8181/8183) ===$(NC)"
	@ss -tlnp | grep -E '(:80|:443|:8090|:8091|:8181|:8183)' || true

chatbot-check:
	@echo "$(BLUE)=== Chatbot Path Checks ===$(NC)"
	@EMAIL="$${CHATBOT_TEST_EMAIL}"; \
	PASS="$${CHATBOT_TEST_PASSWORD}"; \
	if [ -z "$$EMAIL" ] || [ -z "$$PASS" ]; then \
		echo "Missing required credentials."; \
		echo "Usage: CHATBOT_TEST_EMAIL=<email> CHATBOT_TEST_PASSWORD=<password> make chatbot-check"; \
		exit 1; \
	fi; \
	BODY="{\"email\":\"$$EMAIL\",\"password\":\"$$PASS\"}"; \
	code=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8181/health || true); \
	printf "8181 /health => %s" "$$code"; \
	if echo "$$code" | grep -Eq '^[1-4][0-9][0-9]$$'; then echo "  [ok]"; else echo "  [fail]"; fi; \
	code=$$(curl -s -o /dev/null -w "%{http_code}" \
		http://localhost:8090/api/v1/login -X POST -H "Content-Type: application/json" -d "$$BODY" || true); \
	printf "8090 /api/v1/login => %s" "$$code"; \
	if echo "$$code" | grep -Eq '^[1-4][0-9][0-9]$$'; then echo "  [ok]"; else echo "  [fail]"; fi; \
	code=$$(curl -s -o /dev/null -w "%{http_code}" \
		http://localhost:8091/api/v1/login -X POST -H "Host: chatbot-dev.sourri.com" -H "Content-Type: application/json" -d "$$BODY" || true); \
	printf "8091 /api/v1/login => %s" "$$code"; \
	if echo "$$code" | grep -Eq '^[1-4][0-9][0-9]$$'; then echo "  [ok]"; else echo "  [fail]"; fi

recover-chatbot:
	@echo "$(GREEN)Running ordered chatbot recovery...$(NC)"
	$(MAKE) init
	$(MAKE) ssl-up
	$(MAKE) proxy-up
	$(MAKE) diagnose
	$(MAKE) chatbot-check
 
 


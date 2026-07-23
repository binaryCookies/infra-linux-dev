#!/usr/bin/env bash
# =============================================================================
# init-networks.sh — Create required Docker networks (idempotent)
# Safe to run multiple times. Does not modify existing networks.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

create_network() {
  local name=$1
  if docker network inspect "$name" &>/dev/null; then
    echo -e "  ${YELLOW}[exists]${NC}  $name"
  else
    docker network create "$name"
    echo -e "  ${GREEN}[created]${NC} $name"
  fi
}

echo "Initializing Docker networks..."
echo ""

# Shared reverse-proxy network (nginx ↔ all services)
create_network "proxy-network"

# chatbot-api backend network
create_network "backend-chatbot-network"

# sourri-api backend network
create_network "apiportfolio-backend"

echo ""
echo -e "${GREEN}Done.${NC}"
echo ""
echo "Note: frappe_docker_frappe_network is managed by ERPNext (frappe_docker)."
echo "      Start ERPNext first if the reverse proxy needs to route to it."

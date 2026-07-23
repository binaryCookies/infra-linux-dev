#!/bin/bash
echo " Pre-Flight Checks for Nginx Reverse Proxy"
echo "=============================================="

echo -e "\n Checking Docker Networks..."
echo "================================"

echo -e "\n Required Networks:"
echo "  frappe_docker_frappe_network"
echo "  backend-chatbot-network"
echo "  proxy-network (will be created)"

echo -e "\n Existing Networks:"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

echo -e "\n2️ Checking if required networks exist..."
if docker network inspect frappe_docker_frappe_network &>/dev/null; then
    echo "   frappe_docker_frappe_network EXISTS"
else
    echo "   frappe_docker_frappe_network MISSING"
    echo "     Run: cd ~/workspace/applications/ERPNext/frappe_docker && docker compose -f pwd.yml up -d"
fi

if docker network inspect backend-chatbot-network &>/dev/null; then
    echo "   backend-chatbot-network EXISTS"
else
    echo "   backend-chatbot-network MISSING"
    echo "     Run: cd ~/workspace/applications/chatbot-api && make network"
fi

echo -e "\n Checking Docker Compose Configuration..."
cd ~/workspace/applications/reverse-proxy
docker compose config > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   docker-compose.yml is valid"
else
    echo "   docker-compose.yml has errors"
    docker compose config
    exit 1
fi

echo -e "\n Testing Nginx Configuration Files..."
docker compose run --rm nginx nginx -t 2>&1
if [ $? -eq 0 ]; then
    echo "   Nginx configs are valid"
else
    echo "   Nginx configs have errors"
    exit 1
fi

echo -e "\n Checking Port Availability..."
if sudo netstat -tlnp | grep -q ':80 '; then
    echo "    Port 80 is already in use:"
    sudo netstat -tlnp | grep ':80 '
    echo "     You may need to stop Apache first"
else
    echo "   Port 80 is available"
fi

if sudo netstat -tlnp | grep -q ':443 '; then
    echo "    Port 443 is already in use:"
    sudo netstat -tlnp | grep ':443 '
else
    echo "   Port 443 is available"
fi

echo -e "\n Checking Target Containers..."
echo "  Frappe Frontend:"
if docker ps | grep -q frappe_docker-frontend-1; then
    echo "     frappe_docker-frontend-1 is running"
else
    echo "     frappe_docker-frontend-1 is NOT running"
fi

echo "  Chatbot Backend:"
if docker ps | grep -q chatbot-api-dev-backend-chatbot-1; then
    echo "     chatbot-api-dev-backend-chatbot-1 is running"
else
    echo "     chatbot-api-dev-backend-chatbot-1 is NOT running"
fi

echo -e "\n Pre-flight check complete!"
echo "================================"
echo -e "\nNext steps:"
echo "  1. Resolve any  errors above"
echo "  2. Stop Apache if port 80 is in use: sudo systemctl stop apache2"
echo "  3. Start nginx: docker compose up -d"
echo "  4. Check logs: docker compose logs -f nginx"


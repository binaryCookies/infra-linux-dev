#!/bin/bash
# ============================================
# Test All Services Script
# ============================================
# Purpose: Verify all services are accessible through nginx

echo " Testing All Services Through Nginx Reverse Proxy"
echo "===================================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test function
test_http() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $(echo $url | sed 's|http://||')" "$url" 2>/dev/null)
    
    if [[ "$response" == "$expected_code" ]] || [[ "$response" =~ ^(200|301|302)$ ]]; then
        echo -e "${GREEN} PASS${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED} FAIL${NC} (HTTP $response, expected $expected_code)"
        return 1
    fi
}

test_json() {
    local name="$1"
    local url="$2"
    local json_key="$3"
    
    echo -n "Testing $name... "
    
    response=$(curl -s "$url" 2>/dev/null)
    
    if echo "$response" | jq -e ".$json_key" > /dev/null 2>&1; then
        value=$(echo "$response" | jq -r ".$json_key")
        echo -e "${GREEN} PASS${NC} ($json_key: $value)"
        return 0
    else
        echo -e "${RED} FAIL${NC} (Invalid JSON or missing key)"
        return 1
    fi
}

passed=0
failed=0

echo -e "\n1️ Container Services"
echo "================================"

# ERPNext
test_http "ERPNext" "http://paoude-erp.sourri.com" "200"
[ $? -eq 0 ] && ((passed++)) || ((failed++))

# Chatbot API Health
test_json "Chatbot API Health" "http://dev.245bates.sourri.com/health" "status"
[ $? -eq 0 ] && ((passed++)) || ((failed++))

# SSL Service
test_json "SSL Service" "http://api.local/health" "status"
[ $? -eq 0 ] && ((passed++)) || ((failed++))

echo -e "\n2️ Apache-Backed Services"
echo "================================"

# API Portfolio
test_http "API Portfolio" "http://dev.sourri.com" "200"
[ $? -eq 0 ] && ((passed++)) || ((failed++))

# Yanalkamal Dev (adjust domain as needed)
test_http "Yanalkamal Dev" "http://dev.yanalkamal.com" "200"
[ $? -eq 0 ] && ((passed++)) || ((failed++))

# Yanalkamal Prod
test_http "Yanalkamal Prod" "http://yanalkamal.com" "200"
[ $? -eq 0 ] && ((passed++)) || ((failed++))

# Miniature Spork
test_http "Miniature Spork" "http://miniature-spork.sourri.com" "200"
[ $? -eq 0 ] && ((passed++)) || ((failed++))

echo -e "\n3️ Direct Backend Tests (Bypass Nginx)"
echo "================================"

# Test Apache on high ports directly
echo -n "Testing Apache Port 8081... "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 | grep -q "200\|302"; then
    echo -e "${GREEN} PASS${NC}"
    ((passed++))
else
    echo -e "${RED} FAIL${NC}"
    ((failed++))
fi

echo -n "Testing Apache Port 8082... "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8082 | grep -q "200\|302"; then
    echo -e "${GREEN} PASS${NC}"
    ((passed++))
else
    echo -e "${RED} FAIL${NC}"
    ((failed++))
fi

echo -e "\n4️⃣ Nginx Container Health"
echo "================================"

if docker ps | grep -q "reverse-proxy.*nginx.*Up"; then
    echo -e "${GREEN} Nginx container is running${NC}"
    ((passed++))
else
    echo -e "${RED}❌ Nginx container is NOT running${NC}"
    ((failed++))
fi

if docker compose -f ~/workspace/applications/reverse-proxy/docker-compose.yml ps | grep -q "healthy"; then
    echo -e "${GREEN} Nginx health check passing${NC}"
    ((passed++))
else
    echo -e "${YELLOW}  Nginx health check status unclear${NC}"
fi

echo -e "\n5️⃣ Port Availability Check"
echo "================================"

echo -n "Checking port 80... "
if sudo netstat -tlnp 2>/dev/null | grep -q ":80.*nginx"; then
    echo -e "${GREEN} Nginx listening on port 80${NC}"
    ((passed++))
elif sudo netstat -tlnp 2>/dev/null | grep -q ":80.*apache"; then
    echo -e "${RED} Apache still on port 80${NC}"
    ((failed++))
else
    echo -e "${YELLOW}  Nothing listening on port 80${NC}"
fi

echo -e "\n================================"
echo -e "   ${GREEN}Passed: $passed${NC}"
echo -e "   ${RED}Failed: $failed${NC}"
echo -e "================================"

if [ $failed -eq 0 ]; then
    echo -e "${GREEN} All tests passed!${NC}"
    exit 0
else
    echo -e "${RED} Some tests failed. Check logs:${NC}"
    echo "   docker compose -f ~/workspace/applications/reverse-proxy/docker-compose.yml logs nginx"
    exit 1
fi

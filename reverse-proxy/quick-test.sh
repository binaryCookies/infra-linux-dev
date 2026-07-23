#!/bin/bash
# Quick test script to verify each service individually

echo "🧪 Quick Service Tests"
echo "======================"

# Test function with better output
test_service() {
    local name="$1"
    local url="$2"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$url" 2>/dev/null)
    
    if [[ "$response" =~ ^(200|301|302)$ ]]; then
        echo " $response"
        return 0
    else
        echo " $response (or timeout)"
        return 1
    fi
}

echo ""
echo "1️ Testing Backend Services Directly"
echo "======================================"

test_service "Apache 8081 (API Portfolio)" "http://localhost:8081"
test_service "Apache 8082 (Yanalkamal Dev)" "http://localhost:8082"
test_service "Apache 8083 (Yanalkamal Prod)" "http://localhost:8083"
test_service "Apache 8084 (Miniature Spork)" "http://localhost:8084"

echo ""
echo "2️ Testing Through Nginx Reverse Proxy"
echo "=========================================="

test_service "ERPNext" "http://paoude-erp.sourri.com"
test_service "Chatbot API" "http://dev.245bates.sourri.com/health"
test_service "API Portfolio" "http://dev.sourri.com"
test_service "Yanalkamal Dev" "http://dev.yanalkamal.com"
test_service "Yanalkamal Prod" "http://yanalkamal.com"
test_service "Miniature Spork" "http://staging.sourri.com"

echo ""
echo "3️ Port Status"
echo "==============="

echo "Nginx on port 80:"
sudo netstat -tlnp | grep ':80 ' || echo "  Not listening"

echo "Nginx on port 443:"
sudo netstat -tlnp | grep ':443 ' || echo "  Not listening"

echo "Apache ports:"
sudo netstat -tlnp | grep apache2 | awk '{print "  " $4}' | sort -u

echo ""
echo "4️ Container Health"
echo "===================="

docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(nginx|frappe|chatbot)"

echo ""
echo " Quick test complete!"

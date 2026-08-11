#!/bin/bash
#=============================================================================
# SSL Certificate Setup Script
# Uses certbot to obtain Let's Encrypt certificates for all domains
#=============================================================================

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
EMAIL="admin@sourri.com"  # Update with your email
REVERSE_PROXY_DIR="${HOME}/workspace/infrastructure/reverse-proxy"
SSL_DIR="${REVERSE_PROXY_DIR}/ssl"

# Domains to certify
DOMAINS=(
    "erp.sourri.com"
    "dev.245bates.sourri.com"
    "hema-pro.sourri.com"
    "dev.sourri.com"
    "staging.sourri.com"
    "dev.yanalkamal.com"
    "yanalkamal.com"
)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SSL Certificate Setup with Let's Encrypt${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "This script will:"
echo "1. Stop nginx reverse proxy temporarily"
echo "2. Obtain SSL certificates using certbot standalone"
echo "3. Copy certificates to ${SSL_DIR}"
echo "4. Restart nginx with SSL enabled"
echo ""
echo -e "${YELLOW}Email for Let's Encrypt:${NC} ${EMAIL}"
echo -e "${YELLOW}Domains:${NC}"
for domain in "${DOMAINS[@]}"; do
    echo "  - $domain"
done
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

#=============================================================================
# Step 1: Stop nginx reverse proxy
#=============================================================================
echo -e "\n${GREEN}[1/5] Stopping nginx reverse proxy...${NC}"
cd "${REVERSE_PROXY_DIR}"
docker compose down

#=============================================================================
# Step 2: Obtain certificates for each domain
#=============================================================================
echo -e "\n${GREEN}[2/5] Obtaining SSL certificates...${NC}"

for domain in "${DOMAINS[@]}"; do
    echo -e "\n${YELLOW}Processing: ${domain}${NC}"
    
    # Check if certificate already exists and is valid
    if sudo certbot certificates -d "${domain}" 2>/dev/null | grep -q "Certificate Name: ${domain}"; then
        echo -e "${YELLOW}Certificate exists. Checking expiry...${NC}"
        
        # Renew if needed
        sudo certbot renew --cert-name "${domain}" --standalone --non-interactive
    else
        echo -e "${YELLOW}Obtaining new certificate...${NC}"
        
        # Obtain new certificate
        sudo certbot certonly \
            --standalone \
            --non-interactive \
            --agree-tos \
            --email "${EMAIL}" \
            -d "${domain}" \
            --preferred-challenges http \
            --http-01-port 80
    fi
    
    # Create domain directory in ssl/
    mkdir -p "${SSL_DIR}/${domain}"
    
    # Copy certificates to our ssl directory
    if [ -d "/etc/letsencrypt/live/${domain}" ]; then
        echo -e "${GREEN}Copying certificates to ${SSL_DIR}/${domain}${NC}"
        sudo cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "${SSL_DIR}/${domain}/"
        sudo cp "/etc/letsencrypt/live/${domain}/privkey.pem" "${SSL_DIR}/${domain}/"
        sudo chown -R ob1:ob1 "${SSL_DIR}/${domain}"
        sudo chmod 644 "${SSL_DIR}/${domain}/fullchain.pem"
        sudo chmod 600 "${SSL_DIR}/${domain}/privkey.pem"
        echo -e "${GREEN}✓ Certificate obtained for ${domain}${NC}"
    else
        echo -e "${RED}✗ Failed to obtain certificate for ${domain}${NC}"
    fi
done

#=============================================================================
# Step 3: Create SSL configuration snippets
#=============================================================================
echo -e "\n${GREEN}[3/5] Creating SSL configuration snippets...${NC}"

# Create SSL configuration snippet
cat > "${REVERSE_PROXY_DIR}/ssl-params.conf" <<'EOF'
# SSL Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

# OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Security headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
EOF

echo -e "${GREEN}Created ssl-params.conf${NC}"

#=============================================================================
# Step 4: Update nginx configs to support SSL
#=============================================================================
echo -e "\n${GREEN}[4/5] SSL certificates ready. You can now update nginx configs.${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update each conf.d/*.conf file to include SSL configuration"
echo "2. Run: ./enable-ssl-configs.sh (automated script)"
echo "3. Or manually edit each config to add HTTPS server blocks"

#=============================================================================
# Step 5: Start nginx
#=============================================================================
echo -e "\n${GREEN}[5/5] Starting nginx reverse proxy...${NC}"
cd "${REVERSE_PROXY_DIR}"
docker compose up -d

# Wait for nginx to start
sleep 3

# Check status
if docker compose ps nginx | grep -q "Up"; then
    echo -e "${GREEN}✓ Nginx started successfully${NC}"
else
    echo -e "${RED}✗ Nginx failed to start. Check logs:${NC}"
    echo "  docker compose logs nginx"
    exit 1
fi

#=============================================================================
# Summary
#=============================================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SSL Certificate Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Certificates obtained for:"
for domain in "${DOMAINS[@]}"; do
    if [ -f "${SSL_DIR}/${domain}/fullchain.pem" ]; then
        echo -e "  ${GREEN}✓${NC} $domain"
    else
        echo -e "  ${RED}✗${NC} $domain"
    fi
done
echo ""
echo -e "${YELLOW}Certificate locations:${NC}"
echo "  - nginx: ${SSL_DIR}/<domain>/"
echo "  - letsencrypt: /etc/letsencrypt/live/<domain>/"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run: ./enable-ssl-configs.sh to update nginx configs for HTTPS"
echo "2. Test: curl -I https://paoude-erp.sourri.com"
echo "3. Setup auto-renewal: sudo systemctl status certbot.timer"
echo ""
echo -e "${YELLOW}Auto-renewal test:${NC}"
echo "  sudo certbot renew --dry-run"

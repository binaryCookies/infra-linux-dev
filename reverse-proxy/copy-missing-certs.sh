#!/bin/bash
#=============================================================================
# Copy Missing SSL Certificates from Let's Encrypt to nginx ssl directory
#=============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SSL_DIR="/home/ob1/workspace/applications/reverse-proxy/ssl"

echo -e "${GREEN}Copying missing SSL certificates...${NC}"
echo ""

# Domains to copy
DOMAINS=(
    "paoude-erp.sourri.com"
    "staging.sourri.com"
    "dev.245bates.sourri.com"
    "dev.sourri.com"
)

for domain in "${DOMAINS[@]}"; do
    echo -e "${YELLOW}Processing: ${domain}${NC}"
    
    if sudo test -d "/etc/letsencrypt/live/${domain}"; then
        # Create directory
        mkdir -p "${SSL_DIR}/${domain}"
        
        # Copy certificates
        sudo cp "/etc/letsencrypt/live/${domain}/fullchain.pem" "${SSL_DIR}/${domain}/"
        sudo cp "/etc/letsencrypt/live/${domain}/privkey.pem" "${SSL_DIR}/${domain}/"
        
        # Fix ownership
        sudo chown -R ob1:ob1 "${SSL_DIR}/${domain}"
        chmod 644 "${SSL_DIR}/${domain}/fullchain.pem"
        chmod 600 "${SSL_DIR}/${domain}/privkey.pem"
        
        echo -e "  ${GREEN} Copied${NC}"
        
        # Show cert info
        echo -e "  Expires: $(openssl x509 -in ${SSL_DIR}/${domain}/fullchain.pem -noout -enddate | cut -d= -f2)"
    else
        echo -e "  ${YELLOW} No Let's Encrypt cert found${NC}"
    fi
    echo ""
done

echo -e "${GREEN}Verifying all SSL certificates:${NC}"
ls -lh "${SSL_DIR}"/*/fullchain.pem | awk '{print $9}' | sed 's|.*/\([^/]*\)/.*|\1|' | sort | while read domain; do
    echo -e "  ${GREEN} ${NC} $domain"
done

echo ""
echo -e "${GREEN}Done! All certificates copied.${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update nginx configs: ./enable-ssl-configs.sh"
echo "2. Start nginx: docker compose up -d"
echo "3. Test: curl -I https://paoude-erp.sourri.com"

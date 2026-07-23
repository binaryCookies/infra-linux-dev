
```bash
# cd to reverse-proxy directory stop container to free port 80 (docker compose down)
# If DNS is fully propagated, run certbot in standalone mode to obtain/renew cert for
# ex. <domain>.sourri.com
# Copy certs from default certbot location to reverse-proxy ssl directory
# Restart nginx container

# EXAMPLE
cd ~/workspace/applications/reverse-proxy
docker compose down
sudo certbot certonly --standalone -d erp.sourri.com \
  --non-interactive --agree-tos --email admin@sourri.com
sudo mkdir -p ssl/erp.sourri.com
sudo cp /etc/letsencrypt/live/erp.sourri.com/fullchain.pem ssl/erp.sourri.com/
sudo cp /etc/letsencrypt/live/erp.sourri.com/privkey.pem ssl/erp.sourri.com/
docker compose up -d
```
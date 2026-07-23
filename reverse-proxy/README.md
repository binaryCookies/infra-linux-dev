# Reverse Proxy

NGINX reverse proxy running in Docker. Handles SSL termination for all domains and proxies to backends over plain HTTP.

## Architecture

---

## Domain → Backend Mapping

| Domain | NGINX Config | Backend | SSL Cert |
|---|---|---|---|
| `yanalkamal.com` | `yanalkamal-prod.conf` | Apache `:8083` | LE `yanalkamal.com-0001` |
| `dev.yanalkamal.com` | `yanalkamal-dev.conf` | Apache `:8082` | Self-signed (replace when LE issued) |
| `dev.sourri.com` | `api-portfolio.conf` | Apache `:8084` | LE `dev.sourri.com` |
| `paoude-erp.sourri.com` | `erpnext.conf` | Docker container | — |
| `dev.245bates.sourri.com` | `chatbot-api.conf` | Docker container | — |
| `api.local` | `ssl-service.conf` | Docker container | — |

**Apache port assignments** (`/etc/apache2/ports.conf`):

| Port | Apache vhost |
|---|---|
| 8081 | (internal/legacy) |
| 8082 | `yanalkamal.com-dev.conf` |
| 8083 | `yanalkamal.com-prod.conf` |
| 8084 | `apiPortfolio.sourri-dev.conf` |

---

## SSL Certificates

Certs are copied from Let's Encrypt into `ssl/` for the Docker container to mount (volume: `./ssl:/etc/nginx/ssl`).

| Domain | Source | Expires |
|---|---|---|
| `yanalkamal.com` | `/etc/letsencrypt/live/yanalkamal.com-0001/` | 2026-04-08 |
| `dev.sourri.com` | `/etc/letsencrypt/live/dev.sourri.com/` | — |
| `dev.yanalkamal.com` | Self-signed in `ssl/dev.yanalkamal.com/` | 2027-02-18 |

### Renew a Let's Encrypt cert and redeploy

```bash
sudo certbot renew --cert-name <cert-name>
sudo cp /etc/letsencrypt/live/<cert-name>/fullchain.pem ssl/<domain>/fullchain.pem
sudo cp /etc/letsencrypt/live/<cert-name>/privkey.pem   ssl/<domain>/privkey.pem
sudo chown -R ob1:ob1 ssl/
docker compose restart nginx
```

### Issue a new LE cert for dev.yanalkamal.com (replaces self-signed)
```bash
sudo certbot certonly --nginx -d dev.yanalkamal.com
sudo cp /etc/letsencrypt/live/dev.yanalkamal.com/fullchain.pem ssl/dev.yanalkamal.com/fullchain.pem
sudo cp /etc/letsencrypt/live/dev.yanalkamal.com/privkey.pem   ssl/dev.yanalkamal.com/privkey.pem
sudo chown -R ob1:ob1 ssl/
docker compose restart nginx
```
## Operations

```bash
# Reload config without downtime
docker compose exec nginx nginx -s reload

# Full restart
docker compose restart nginx

# Test config before applying
docker compose exec nginx nginx -t

# View logs
docker compose logs -f nginx
```

## Adding a New Site
- Create conf.d/<name>.conf with HTTP→HTTPS redirect and SSL server block.
- Copy certs into ssl/<domain>/ (or generate self-signed, see below).
- If backend is Apache: add a new Listen <port> to ports.conf and create a plain-HTTP vhost on that port.
- Test and reload: docker compose exec nginx nginx -t && docker compose exec nginx nginx -s reload

## Self-signed cert (dev/staging):
```bash
mkdir -p ssl/<domain>
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/<domain>/privkey.pem \
  -out    ssl/<domain>/fullchain.pem \
  -subj "/CN=<domain>" -addext "subjectAltName=DNS:<domain>"
```

# Troubleshooting

## NGINX won't start — config error
```bash
docker compose exec nginx nginx -t
docker compose logs nginx
```

## Apache won't start — SSL error on high port
- Check that no Apache vhost on a high port has SSLEngine on — SSL is terminated at NGINX, Apache vhosts must be plain HTTP.
```bash
sudo apache2ctl -t
sudo tail -20 /var/log/apache2/error.log
```

## 502 Bad Gateway
- Apache is not running or not listening on the expected port.
```bash
sudo systemctl status apache2
sudo netstat -tlnp | grep apache2
```

## Testing from the same server (hairpin NAT workaround)
- DNS resolves to this server's public IP, so standard curl loops back. Use --resolve to force local:
```bash
curl -sI --resolve <domain>:443:127.0.0.1 https://<domain>
# self-signed cert: add -k
curl -sI --resolve dev.yanalkamal.com:443:127.0.0.1 https://dev.yanalkamal.com -k
```
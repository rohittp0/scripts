#!/bin/bash

# Exit on errors
set -e

DOMAIN="$1"
PROXY_PASS="$2"

if [ -z "$DOMAIN" ] || [ -z "$PROXY_PASS" ]; then
    echo "Usage: $0 <domain> <proxy_pass_url>"
    echo "Example: $0 staging.dashboard.lascade.com http://localhost:8000"
    exit 1
fi

# Set the Nginx config file path
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

echo "Creating Nginx config for $DOMAIN → $PROXY_PASS"

# Create the Nginx config with sudo
sudo bash -c "cat > $NGINX_CONF" <<EOF
# Auto-generated Nginx configuration
# Domain: $DOMAIN

server {
    listen 80;
    server_name $DOMAIN;

    # Redirect all HTTP to HTTPS (Certbot will expand this into SSL block)
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    # SSL certificate paths (Certbot will manage these)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # HSTS (recommended for production)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";

    # Max upload size
    client_max_body_size 100M;

    # Proxy headers
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$server_name;

    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    # WebSocket timeout (optimisation B)
    proxy_read_timeout 300s;

    # Enable compression (optimisation C)
    gzip on;
    gzip_types text/css application/json text/javascript application/javascript;
    gzip_proxied any;
    gzip_min_length 1000;

    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Proxy to backend
    location / {
        proxy_pass $PROXY_PASS;
    }
}
EOF

# Enable the site (create symlink in sites-enabled)
sudo ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN"

echo "Testing Nginx configuration..."
sudo nginx -t

echo "Reloading Nginx..."
sudo systemctl reload nginx

echo "Completed! Config available at: $NGINX_CONF"

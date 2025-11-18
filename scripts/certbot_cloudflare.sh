#!/bin/bash

# Exit on errors
set -e

# Input validation
if [ $# -lt 2 ]; then
    echo "Usage: $0 <cloudflare_api_token> <domain_name>"
    exit 1
fi

# Check if Cloudflare plugin is installed, if not, install it
if ! dpkg -l | grep -q python3-certbot-dns-cloudflare; then
    echo "Cloudflare plugin not found, installing..."
    sudo apt update
    sudo apt install python3-certbot-dns-cloudflare -y
fi

CLOUDFLARE_API_TOKEN="$1"
DOMAIN="$2"

# Create a credentials file for Cloudflare API token
CF_CREDS_FILE="/etc/letsencrypt/cloudflare.ini"

echo "Creating Cloudflare credentials file..."
sudo bash -c "echo 'dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN' > $CF_CREDS_FILE"
sudo chmod 600 $CF_CREDS_FILE

# Run Certbot to obtain the certificate using Cloudflare DNS plugin
echo "Running Certbot to issue certificate for $DOMAIN..."
sudo certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials $CF_CREDS_FILE \
    -d $DOMAIN

# Test the certificate renewal
echo "Testing the certificate renewal process..."
sudo certbot renew --dry-run

echo "Certificate for $DOMAIN issued successfully!"

#!/bin/bash
# SSH wrapper to connect to Digital Ocean droplets by domain name
# Usage: ssh-droplet.sh [user@]<domain> [additional ssh args]
# Flags:
#   --refresh: Bypass cache and force fresh lookup
#   --ip: Print IP address and exit (don't SSH)

set -euo pipefail

CACHE_DIR="${HOME}/.cache/ssh-droplet"

# Parse arguments
REFRESH=false
IP_ONLY=false
DOMAIN=""
USERNAME=""
SSH_ARGS=()

for arg in "$@"; do
    if [ "$arg" = "--refresh" ]; then
        REFRESH=true
    elif [ "$arg" = "--ip" ]; then
        IP_ONLY=true
    elif [[ "$arg" == *"@"* ]]; then
        USERNAME="${arg%%@*}"
        DOMAIN="${arg#*@}"
    else
        SSH_ARGS+=("$arg")
    fi
done

if [ -z "$DOMAIN" ] || [ -z "$USERNAME" ]; then
    echo "Usage: $0 <user>@<domain> [--refresh] [--ip] [ssh-options]"
    exit 1
fi

# Check if doctl is installed
if ! command -v doctl &> /dev/null; then
    echo "Error: doctl is not installed or not in PATH"
    echo "Install from: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi

CACHE_FILE="${CACHE_DIR}/${DOMAIN}"

# Function to get IP from doctl
get_ip_from_doctl() {
    echo "Looking up droplet: $DOMAIN..." >&2

    # Get droplet IP using doctl
    IP=$(doctl compute droplet list --format Name,PublicIPv4 --no-header | \
         grep "^${DOMAIN} " | \
         awk '{print $2}')

    if [ -z "$IP" ]; then
        echo "Error: Could not find droplet named '$DOMAIN'" >&2
        exit 1
    fi

    echo "$IP"
}

# Check cache if enabled
if [ "$REFRESH" = "false" ] && [ -f "$CACHE_FILE" ]; then
    IP=$(cat "$CACHE_FILE")
else
    IP=$(get_ip_from_doctl)

    # Create/update cache
    mkdir -p "$CACHE_DIR"
    echo "$IP" > "$CACHE_FILE"
    echo "Cached IP for future use: $IP" >&2
fi

# If --ip flag is set, just print IP and exit
if [ "$IP_ONLY" = "true" ]; then
    echo "$IP"
    exit 0
fi

# SSH into the droplet with the resolved IP and any additional arguments
ssh "${USERNAME}@${IP}" ${SSH_ARGS[@]+"${SSH_ARGS[@]}"}

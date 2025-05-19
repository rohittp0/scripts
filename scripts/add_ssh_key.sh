#!/bin/bash

# Check if a public key is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <public_key>"
    exit 1
fi

PUBLIC_KEY="$1"
AUTHORIZED_KEYS_FILE="$HOME/.ssh/authorized_keys"

# Ensure ~/.ssh directory exists
if [ ! -d "$HOME/.ssh" ]; then
    mkdir -m 700 "$HOME/.ssh"
fi

# Append the public key to the authorized_keys file
echo "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS_FILE"

echo "Public key added to $AUTHORIZED_KEYS_FILE"

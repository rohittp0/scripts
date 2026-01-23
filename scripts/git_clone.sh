#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Check if both arguments are provided
if [ $# -lt 2 ]; then
    echo >&2 "Usage: $0 <key_name> <clone_url>"
    echo >&2 "Example: $0 my-key git@github.com:user/repo.git"
    exit 1
fi

KEY_NAME="$1"
CLONE_URL="$2"
KEY_PATH="$HOME/.ssh/$KEY_NAME"

# Check if the key exists
if [ ! -f "$KEY_PATH" ]; then
    echo >&2 "Error: SSH key not found at $KEY_PATH"
    exit 1
fi

# Check if it's a private key (should contain PRIVATE KEY)
if ! grep -q "PRIVATE KEY" "$KEY_PATH"; then
    echo >&2 "Error: $KEY_PATH does not appear to be a private SSH key"
    exit 1
fi

# Set SSH_KEY_PATH environment variable for git to use the specific key
export GIT_SSH_COMMAND="ssh -i $KEY_PATH -o StrictHostKeyChecking=no"

# Perform the git clone
echo "Cloning repository from $CLONE_URL using key $KEY_NAME..."
git clone "$CLONE_URL"

echo "Repository cloned successfully!"

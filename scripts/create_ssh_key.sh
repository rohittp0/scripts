#!/bin/bash

# Check if a key name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <key_name>"
    exit 1
fi

KEY_PATH="$HOME/.ssh/$1"

# Check if the key already exists
if [ -f "$KEY_PATH" ]; then
    echo "Warning: The key $KEY_PATH already exists. Skipping creation."
    exit 0
fi

# Generate SSH key
ssh-keygen -f "$KEY_PATH" -N ""

# Start the SSH agent if not running
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)"
fi

# Add the SSH key to the agent
ssh-add "$KEY_PATH"

# Print the public key
cat "${KEY_PATH}.pub"

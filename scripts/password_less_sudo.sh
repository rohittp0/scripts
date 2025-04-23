#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Check if a username is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME="$1"

# Check if user exists, fail if not
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' exists."
else
    echo "Error: User '$USERNAME' does not exist."
    exit 1
fi

# Add user to the sudo group
usermod -aG sudo "$USERNAME"
echo "Added '$USERNAME' to the sudo group."

# Setup passwordless sudo for the user
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USERNAME"
chmod 440 /etc/sudoers.d/"$USERNAME"
echo "Set up passwordless sudo for '$USERNAME'."

echo "Script completed successfully."

#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Create user 'ubuntu' if it does not exist
if id "ubuntu" &>/dev/null; then
    echo "User 'ubuntu' already exists."
else
    useradd -m -s /bin/bash ubuntu
    echo "User 'ubuntu' created."
fi

# Add 'ubuntu' to the sudo group
usermod -aG sudo ubuntu
echo "Added 'ubuntu' to the sudo group."

# Setup passwordless sudo for 'ubuntu'
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 440 /etc/sudoers.d/ubuntu
echo "Set up passwordless sudo for 'ubuntu'."

# Copy /root/.ssh to /home/ubuntu/.ssh and change ownership
if [ -d /root/.ssh ]; then
    cp -r /root/.ssh /home/ubuntu/
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    chmod 600 /home/ubuntu/.ssh/*
    echo "Copied /root/.ssh to /home/ubuntu/.ssh and updated permissions."
else
    echo "/root/.ssh does not exist. Skipping copy."
fi

echo "Script completed successfully."

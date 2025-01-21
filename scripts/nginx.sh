#!/bin/bash

set -e

COLOR_GREEN='\033[0;32m'
NO_COLOR='\033[0m'

# Update package lists
sudo apt update

# Install nginx
sudo apt install -y nginx

# Enable nginx service
sudo systemctl enable nginx

# Install certbot
sudo snap install --classic certbot

# Start nginx service
sudo systemctl start nginx

echo -e "${COLOR_GREEN}nginx and certbot installed and started successfully.${NO_COLOR}"

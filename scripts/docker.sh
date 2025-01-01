#!/bin/bash

set -e

COLOR_GREEN='\033[0;32m'
NO_COLOR='\033[0m'

# Install docker if not already installed
if ! command -v docker &> /dev/null
then
    echo "Docker not found. Installing Docker..."

    sudo apt update

    # Install required packages
    sudo apt install -y ca-certificates curl gnupg lsb-release

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package lists again
    sudo apt update

    # Install Docker Engine and Docker Compose
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    sudo gpasswd -a $USER docker
    newgrp docker

    echo -e "${COLOR_GREEN}Docker installed successfully.${NO_COLOR}"
fi
#!/bin/bash
set -e

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
NO_COLOR='\033[0m'

# Parse and set defaults
SWAP_SIZE=${1:-2}
SWAP_FILE="/swapfile"
SWAPPINESS=${2:-10}

# Validate SWAP_SIZE: must be a positive integer between 1 and 1024
if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
    echo -e "${COLOR_RED}Error: SWAP_SIZE must be a positive integer${NO_COLOR}" >&2
    exit 1
fi

if [ "$SWAP_SIZE" -lt 1 ] || [ "$SWAP_SIZE" -gt 1024 ]; then
    echo -e "${COLOR_RED}Error: SWAP_SIZE must be between 1 and 1024 GB${NO_COLOR}" >&2
    exit 1
fi

# Validate SWAPPINESS: must be an integer between 0 and 100
if ! [[ "$SWAPPINESS" =~ ^[0-9]+$ ]]; then
    echo -e "${COLOR_RED}Error: SWAPPINESS must be an integer${NO_COLOR}" >&2
    exit 1
fi

if [ "$SWAPPINESS" -lt 0 ] || [ "$SWAPPINESS" -gt 100 ]; then
    echo -e "${COLOR_RED}Error: SWAPPINESS must be between 0 and 100${NO_COLOR}" >&2
    exit 1
fi

echo -e "${COLOR_BLUE}=== Ubuntu Swap Setup Script ===${NO_COLOR}"
echo -e "${COLOR_YELLOW}Swap size: ${SWAP_SIZE}GB${NO_COLOR}"
echo -e "${COLOR_YELLOW}Swappiness: ${SWAPPINESS}${NO_COLOR}"
echo ""

# Check if swap already exists
if swapon --show | grep -q "$SWAP_FILE"; then
    echo -e "${COLOR_YELLOW}Swap file already exists at $SWAP_FILE${NO_COLOR}"
    echo "Current swap status:"
    swapon --show
    free -h
    echo -e "${COLOR_BLUE}Disabling existing swap and recreating...${NO_COLOR}"
    sudo swapoff "$SWAP_FILE"
    sudo rm "$SWAP_FILE"
fi

# Create swap file
echo -e "${COLOR_BLUE}Creating ${SWAP_SIZE}GB swap file...${NO_COLOR}"
if command -v fallocate &> /dev/null; then
    sudo fallocate -l "${SWAP_SIZE}G" "$SWAP_FILE"
else
    sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$((SWAP_SIZE * 1024))" status=progress
fi

# Set correct permissions
echo -e "${COLOR_BLUE}Setting permissions...${NO_COLOR}"
sudo chmod 600 "$SWAP_FILE"

# Make swap
echo -e "${COLOR_BLUE}Formatting swap file...${NO_COLOR}"
sudo mkswap "$SWAP_FILE"

# Enable swap
echo -e "${COLOR_BLUE}Enabling swap...${NO_COLOR}"
sudo swapon "$SWAP_FILE"

# Verify swap is active
echo -e "${COLOR_GREEN}Swap enabled successfully!${NO_COLOR}"
echo ""
echo "Current swap status:"
sudo swapon --show
free -h

# Make swap permanent
if ! grep -q "$SWAP_FILE" /etc/fstab; then
    echo -e "${COLOR_BLUE}Adding swap to /etc/fstab for persistence...${NO_COLOR}"
    echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
    echo -e "${COLOR_GREEN}Swap will persist after reboot.${NO_COLOR}"
else
    echo -e "${COLOR_YELLOW}Swap entry already exists in /etc/fstab${NO_COLOR}"
fi

# Set swappiness
echo -e "${COLOR_BLUE}Configuring swappiness to ${SWAPPINESS}...${NO_COLOR}"
sudo sysctl "vm.swappiness=$SWAPPINESS"

# Make swappiness permanent
if grep -q "^vm.swappiness" /etc/sysctl.conf; then
    sudo sed -i "s/^vm.swappiness.*/vm.swappiness=$SWAPPINESS/" /etc/sysctl.conf
else
    echo "vm.swappiness=$SWAPPINESS" | sudo tee -a /etc/sysctl.conf > /dev/null
fi

echo ""
echo -e "${COLOR_GREEN}=== Swap setup complete! ===${NO_COLOR}"
echo -e "Swap file: $SWAP_FILE"
echo -e "Size: ${SWAP_SIZE}GB"
echo -e "Swappiness: ${SWAPPINESS}"

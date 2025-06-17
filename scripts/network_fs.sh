#!/bin/bash

set -euo pipefail

# Required variables
# HOST - The remote host to connect to
# USER - The user to connect as ( optional defaults to current user )
# FOLDER - The remote folder to mount
# IDENTITY_FILE - The SSH identity file to use

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <remote_host> <remote_folder> <identity_file> [user]" >&2
  exit 1
fi

HOST=$1
FOLDER=$2
IDENTITY_FILE=$3
USER=${4:-$USER}

# Check if sshfs is installed if not install it
if ! command -v sshfs &> /dev/null; then
    echo "sshfs is not installed. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y sshfs
    elif command -v yum &> /dev/null; then
        sudo yum install -y sshfs
    else
        echo "Package manager not supported. Please install sshfs manually."
        exit 1
    fi
fi

# Ensure the mount point exists
if [ ! -d "/home/${USER}/${FOLDER}" ]; then
    echo "Creating mount point directory /home/${USER}/${FOLDER}..."
    mkdir -p "/home/${USER}/${FOLDER}"
fi

# Ensure mount point is empty
if [ "$(ls -A /home/${USER}/${FOLDER})" ]; then
    echo "Mount point /home/${USER}/${FOLDER} is not empty. Please clear it before mounting."
    exit 1
fi

sudo sshfs -o allow_other,default_permissions,identityfile=/home/${USER}/.ssh/${IDENTITY_FILE} ${USER}@${HOST}:${FOLDER} /home/${USER}/${FOLDER}

# Add the mount to fstab for persistence
FSTAB_ENTRY="${USER}@${HOST}:${FOLDER} /home/${USER}/${FOLDER} fuse.sshfs noauto,x-systemd.automount,_netdev,reconnect,identityfile=/home/${USER}/.ssh/${IDENTITY_FILE},allow_other,default_permissions 0 0"

if ! grep -q "${FSTAB_ENTRY}" /etc/fstab; then
    echo "Adding entry to /etc/fstab for persistence..."
    echo "${FSTAB_ENTRY}" | sudo tee -a /etc/fstab > /dev/null
else
    echo "Entry already exists in /etc/fstab."
fi

# Check if the mount was successful
if mountpoint -q "/home/${USER}/${FOLDER}"; then
   echo "Successfully mounted ${FOLDER} from ${HOST} to /home/${USER}/${FOLDER}"
else
    echo "Mount failed. Please check the logs for errors."
    exit 1
fi
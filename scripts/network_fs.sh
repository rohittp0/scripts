#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") HOST REMOTE_DIR IDENTITY_FILE [USER]
Mount a remote directory over SSHFS and add a persistent fstab entry.
  HOST          remote host (ssh target)
  REMOTE_DIR    remote path to mount
  IDENTITY_FILE absolute or ~/ relative path to private key
  USER          local user (defaults to \$USER)
EOF
  exit 1
}

[[ $# -lt 3 ]] && usage

HOST=$1
REMOTE_DIR=$2
IDENTITY_FILE=$3
LOCAL_USER=${4:-$(id -un)}
# Resolve HOME robustly even under sudo
LOCAL_HOME=$(getent passwd "$LOCAL_USER" | cut -d: -f6)
MOUNT_POINT="${LOCAL_HOME}/${REMOTE_DIR//\//_}"  # unique & safe
IDENTITY_PATH=$(realpath -m "$IDENTITY_FILE")                # canonical

# ---------- sanity checks ---------------------------------------------------
# detect & install sshfs
if ! command -v sshfs >/dev/null 2>&1; then
  if   command -v apt   >/dev/null; then sudo apt update && sudo apt install -y sshfs
  elif command -v dnf   >/dev/null; then sudo dnf install -y sshfs
  elif command -v pacman>/dev/null; then sudo pacman -Sy --noconfirm sshfs
  elif command -v zypper>/dev/null; then sudo zypper --non-interactive in sshfs
  elif [[ "$OSTYPE" == "darwin"* ]]; then
         brew list macfuse >/dev/null 2>&1 || brew install macfuse
         brew install sshfs
  else
    echo "⚠️  Unsupported OS. Install sshfs manually." >&2; exit 1
  fi
fi

# Validate identity file exists
if [[ ! -f "$IDENTITY_PATH" ]]; then
  # Check if the file exists in ~/.ssh/
  SSH_IDENTITY_PATH="${LOCAL_HOME}/.ssh/$IDENTITY_FILE"
  if [[ -f "$SSH_IDENTITY_PATH" ]]; then
    echo "Identity file not found at $IDENTITY_PATH, using $SSH_IDENTITY_PATH"
    IDENTITY_PATH="$SSH_IDENTITY_PATH"
  else
    echo "❌ Error: Identity file not found at $IDENTITY_PATH or $SSH_IDENTITY_PATH" >&2
    exit 2
  fi
fi

if mountpoint -q "$MOUNT_POINT"; then
  echo "Already mounted at $MOUNT_POINT"; exit 0
fi
mkdir -p "$MOUNT_POINT"
if [[ -n $(ls -A "$MOUNT_POINT") ]]; then
  echo "Mount point not empty: $MOUNT_POINT"; exit 4
fi

# Ensure .ssh directory exists and add host key to known_hosts if not already present
sudo -u "$LOCAL_USER" mkdir -p "${LOCAL_HOME}/.ssh"
sudo -u "$LOCAL_USER" chmod 700 "${LOCAL_HOME}/.ssh"
if ! sudo -u "$LOCAL_USER" ssh-keygen -F "$HOST" -f "${LOCAL_HOME}/.ssh/known_hosts" >/dev/null 2>&1; then
  echo "Adding $HOST to known_hosts..."
  sudo -u "$LOCAL_USER" ssh-keyscan -H "$HOST" >> "${LOCAL_HOME}/.ssh/known_hosts" 2>/dev/null
  sudo -u "$LOCAL_USER" chmod 644 "${LOCAL_HOME}/.ssh/known_hosts"
fi

# ---------- add to /etc/fstab ----------------------------------------------
FSTAB_OPTS="noauto,user,_netdev,reconnect,\
IdentityFile=${IDENTITY_PATH},allow_other,default_permissions"
FSTAB_LINE="${LOCAL_USER}@${HOST}:${REMOTE_DIR}  ${MOUNT_POINT}  fuse.sshfs  ${FSTAB_OPTS}  0  0"
if ! grep -qsF "$FSTAB_LINE" /etc/fstab; then
  echo "Adding mount entry to /etc/fstab"
  echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
fi

sudo systemctl daemon-reload

# ---------- activate the mount from fstab ----------------------------------
echo "Mounting $HOST:$REMOTE_DIR → $MOUNT_POINT"
sudo mount "$MOUNT_POINT"
echo "✅  Mounted successfully."

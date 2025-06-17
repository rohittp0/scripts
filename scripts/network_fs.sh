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

MOUNT_POINT="${LOCAL_HOME}/${HOST//:/}_${REMOTE_DIR//\//_}"  # unique & safe
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

[[ -r "$IDENTITY_PATH" ]] || { echo "Cannot read key $IDENTITY_PATH"; exit 3; }

if mountpoint -q "$MOUNT_POINT"; then
  echo "Already mounted at $MOUNT_POINT"; exit 0
fi

mkdir -p "$MOUNT_POINT"
if [[ -n $(ls -A "$MOUNT_POINT") ]]; then
  echo "Mount point not empty: $MOUNT_POINT"; exit 4
fi

# ---------- do the mount ----------------------------------------------------
echo "Mounting $HOST:$REMOTE_DIR → $MOUNT_POINT"
sudo sshfs \
  -o IdentityFile="$IDENTITY_PATH" \
  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 \
  -o allow_other,default_permissions \
  "${LOCAL_USER}@${HOST}:$REMOTE_DIR" "$MOUNT_POINT"

# ---------- add to /etc/fstab ----------------------------------------------
FSTAB_OPTS="noauto,x-systemd.automount,_netdev,reconnect,\
IdentityFile=${IDENTITY_PATH},allow_other,default_permissions"

FSTAB_LINE="${LOCAL_USER}@${HOST}:${REMOTE_DIR}  ${MOUNT_POINT}  fuse.sshfs  ${FSTAB_OPTS}  0  0"

if ! grep -qsF "$FSTAB_LINE" /etc/fstab; then
  echo "Persisting mount in /etc/fstab"
  echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
fi

echo "✅  Mounted successfully."

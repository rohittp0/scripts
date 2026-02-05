#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup_nfs.sh <VOLUME_NAME>
#
# Assumptions:
# - Export base path: /srv/nfs/<VOLUME_NAME>
# - Private subnet inferred as /16 from private IP
# - anonuid/anongid fixed to 1001

VOLUME_NAME="${1:-}"
[[ -n "$VOLUME_NAME" ]] || { echo "Usage: $0 <VOLUME_NAME>" >&2; exit 1; }
if [[ ! "$VOLUME_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "VOLUME_NAME must be a single path segment (letters, numbers, ., _, - only)." >&2
  exit 1
fi

ANON_UID=1001
ANON_GID=1001
EXPORT_DIR="/srv/nfs/${VOLUME_NAME}"

# ---- Ensure sudo works ----
if ! sudo -n true 2>/dev/null; then
  echo "Passwordless sudo is required." >&2
  exit 1
fi

# ---- Detect private IP (RFC1918 only) ----
PRIVATE_IP="$(ip -4 addr show \
  | awk '/inet /{print $2}' \
  | cut -d/ -f1 \
  | grep -E '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' \
  | head -n1)"

[[ -n "$PRIVATE_IP" ]] || { echo "Could not detect private IPv4 address." >&2; exit 1; }

# Infer /16 subnet (A.B.0.0/16)
SUBNET="$(echo "$PRIVATE_IP" | awk -F. '{print $1"."$2".0.0/16"}')"

echo "[info] Private IP : $PRIVATE_IP"
echo "[info] Subnet     : $SUBNET"
echo "[info] Export dir : $EXPORT_DIR"

# ---- Install NFS server if missing ----
if ! dpkg -s nfs-kernel-server >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y nfs-kernel-server
fi

# ---- Prepare export directory ----
sudo mkdir -p "$EXPORT_DIR"
sudo chown -R "${ANON_UID}:${ANON_GID}" "$EXPORT_DIR"
sudo chmod -R 775 "$EXPORT_DIR"

# ---- Configure /etc/exports (idempotent) ----
EXPORTS_FILE="/etc/exports"
sudo touch "$EXPORTS_FILE"

# Remove any existing export of this directory
sudo sed -i.bak -E "\|^${EXPORT_DIR}[[:space:]]|d" "$EXPORTS_FILE"

sudo tee -a "$EXPORTS_FILE" >/dev/null <<EOF
${EXPORT_DIR}  ${SUBNET}(rw,sync,no_subtree_check,all_squash,anonuid=${ANON_UID},anongid=${ANON_GID})
EOF

# ---- Bind NFS to private IP only ----
NFS_DEFAULT="/etc/default/nfs-kernel-server"
if sudo grep -q '^RPCNFSDOPTS=' "$NFS_DEFAULT" 2>/dev/null; then
  sudo sed -i -E "s/^RPCNFSDOPTS=.*/RPCNFSDOPTS=\"--host ${PRIVATE_IP}\"/" "$NFS_DEFAULT"
else
  sudo tee -a "$NFS_DEFAULT" >/dev/null <<EOF
RPCNFSDOPTS="--host ${PRIVATE_IP}"
EOF
fi

# ---- Apply configuration ----
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# ---- Firewall hardening (UFW if active) ----
if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -qi "Status: active"; then
  sudo ufw deny 2049 || true
  sudo ufw deny 111  || true
  sudo ufw allow from "$SUBNET" to any port 2049
  sudo ufw allow from "$SUBNET" to any port 111
fi

echo "[ok] NFS export secured and ready."
echo "     Mount from workers with:"
echo "     sudo mount -t nfs4 ${PRIVATE_IP}:${EXPORT_DIR} /mnt/${VOLUME_NAME}"

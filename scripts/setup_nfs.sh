#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup_nfs_manager.sh <VOLUME_NAME> <BIND_IP>
#
# Exports: /srv/nfs/<VOLUME_NAME>
# Binds NFS to <BIND_IP>
# Exports to multiple "host" CIDRs (non-container interfaces) so Docker/Swarm CIDRs are covered.
# SECURITY: uses no_root_squash (root on clients acts as root on the share)

VOLUME_NAME="${1:-}"
BIND_IP="${2:-}"

[[ -n "$VOLUME_NAME" && -n "$BIND_IP" ]] || {
  echo "Usage: $0 <VOLUME_NAME> <BIND_IP>" >&2
  exit 1
}

ANON_UID=1001
ANON_GID=1001
EXPORT_DIR="/srv/nfs/${VOLUME_NAME}"

# ---- Ensure sudo works ----
if ! sudo -n true 2>/dev/null; then
  echo "Passwordless sudo is required." >&2
  exit 1
fi

# ---- Find interface that has this IP ----
IFACE="$(ip -4 -o addr show | awk -v ip="$BIND_IP" '$4 ~ ("^"ip"/") {print $2; exit}')"
[[ -n "$IFACE" ]] || {
  echo "Could not find a local interface with IP ${BIND_IP}." >&2
  exit 1
}

# ---- Build a safe list of CIDRs to allow ----
is_container_iface() {
  local dev="$1"
  [[ "$dev" == "lo" ]] && return 0
  [[ "$dev" == docker* ]] && return 0
  [[ "$dev" == "docker_gwbridge" ]] && return 0
  [[ "$dev" == br-* ]] && return 0
  [[ "$dev" == veth* ]] && return 0
  [[ "$dev" == vxlan* ]] && return 0
  [[ "$dev" == flannel* ]] && return 0
  [[ "$dev" == cni* ]] && return 0
  [[ "$dev" == kube* ]] && return 0
  [[ "$dev" == weave* ]] && return 0
  [[ "$dev" == cali* ]] && return 0
  return 1
}

is_rfc1918() {
  local ip="$1"
  [[ "$ip" =~ ^10\. ]] || \
  [[ "$ip" =~ ^192\.168\. ]] || \
  [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]
}

mapfile -t CIDR_LIST < <(
  ip -4 -o addr show \
  | awk '{print $2, $4}' \
  | while read -r dev cidr; do
      ip="${cidr%%/*}"
      if is_container_iface "$dev"; then
        continue
      fi
      if is_rfc1918 "$ip"; then
        echo "$cidr"
      fi
    done \
  | sort -u
)

BIND_CIDR="$(ip -4 -o addr show dev "$IFACE" | awk -v ip="$BIND_IP" '$4 ~ ("^"ip"/") {print $4; exit}')"
[[ -n "$BIND_CIDR" ]] || { echo "Could not derive CIDR for bind IP ${BIND_IP}." >&2; exit 1; }

CIDR_LIST+=("$BIND_CIDR")
CIDR_LIST=($(printf "%s\n" "${CIDR_LIST[@]}" | sort -u))

for c in "${CIDR_LIST[@]}"; do
  ip="${c%%/*}"
  if ! is_rfc1918 "$ip"; then
    echo "Refusing to export to non-RFC1918 CIDR: $c" >&2
    exit 1
  fi
done

echo "[info] Bind IP        : $BIND_IP"
echo "[info] Interface      : $IFACE"
echo "[info] Allowed CIDRs  : ${CIDR_LIST[*]}"
echo "[info] Export dir     : $EXPORT_DIR"
echo "[warn] no_root_squash enabled: root on clients can act as root on this share."

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
sudo sed -i.bak -E "\|^${EXPORT_DIR}[[:space:]]|d" "$EXPORTS_FILE"

# NOTE:
# - all_squash keeps regular users mapped to anonuid/anongid.
# - no_root_squash lets root keep root privileges for chown/chmod/etc.
EXPORT_LINE="${EXPORT_DIR}"
for cidr in "${CIDR_LIST[@]}"; do
  EXPORT_LINE+="  ${cidr}(rw,sync,no_subtree_check,secure,sec=sys,all_squash,anonuid=${ANON_UID},anongid=${ANON_GID},no_root_squash)"
done
echo "$EXPORT_LINE" | sudo tee -a "$EXPORTS_FILE" >/dev/null

# ---- Bind NFS to the provided IP only ----
NFS_DEFAULT="/etc/default/nfs-kernel-server"
if sudo grep -q '^RPCNFSDOPTS=' "$NFS_DEFAULT" 2>/dev/null; then
  sudo sed -i -E "s/^RPCNFSDOPTS=.*/RPCNFSDOPTS=\"--host ${BIND_IP}\"/" "$NFS_DEFAULT"
else
  echo "RPCNFSDOPTS=\"--host ${BIND_IP}\"" | sudo tee -a "$NFS_DEFAULT" >/dev/null
fi

# ---- Apply configuration ----
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# ---- Firewall hardening (UFW if active) ----
if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -qi "Status: active"; then
  for cidr in "${CIDR_LIST[@]}"; do
    sudo ufw allow from "$cidr" to any port 2049 proto tcp || true
    sudo ufw allow from "$cidr" to any port 2049 proto udp || true
    sudo ufw allow from "$cidr" to any port 111  proto tcp || true
    sudo ufw allow from "$cidr" to any port 111  proto udp || true
  done
  sudo ufw deny 2049/tcp || true
  sudo ufw deny 2049/udp || true
  sudo ufw deny 111/tcp  || true
  sudo ufw deny 111/udp  || true
fi

echo "[ok] NFS export updated."
echo "     Mount test:"
echo "     sudo mount -t nfs4 ${BIND_IP}:${EXPORT_DIR} /mnt/${VOLUME_NAME}"

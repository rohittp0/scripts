#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./setup_nfs_manager.sh <VOLUME_NAME> <BIND_IP>
#
# Example:
#   ./setup_nfs_manager.sh marine_shared 10.116.0.10
#
# Exports: /srv/nfs/<VOLUME_NAME>
# Binds NFS to <BIND_IP>
# Restricts access to the connected subnet of the interface that owns <BIND_IP>

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

# ---- Derive connected subnet CIDR from kernel routes on that interface ----
# Prefer route that contains the bind IP (most correct if iface has multiple subnets)
SUBNET_CIDR="$(
  ip -4 route show dev "$IFACE" proto kernel \
  | awk -v ip="$BIND_IP" '
      function ip2i(s,  a){split(s,a,"."); return a[1]*256^3+a[2]*256^2+a[3]*256+a[4]}
      function in_cidr(ip, cidr,  net,pfx,mask,ipi,neti){
        split(cidr,a,"/"); net=a[1]; pfx=a[2]
        mask = (pfx==0)?0:(and(0xffffffff, lshift(0xffffffff, 32-pfx)))
        ipi=ip2i(ip); neti=ip2i(net)
        return and(ipi,mask)==and(neti,mask)
      }
      {
        cidr=$1
        if (cidr ~ /^[0-9]+\./ && cidr ~ /\/[0-9]+$/) {
          if (in_cidr(ip, cidr)) { print cidr; exit }
        }
      }
    '
)"

# Fallback: use the interface address CIDR if no kernel route match
if [[ -z "$SUBNET_CIDR" ]]; then
  SUBNET_CIDR="$(ip -4 addr show dev "$IFACE" | awk -v ip="$BIND_IP" '$1=="inet" && $2 ~ ("^"ip"/"){print $2; exit}')"
fi

[[ -n "$SUBNET_CIDR" ]] || {
  echo "Could not derive subnet CIDR for IP ${BIND_IP} on iface ${IFACE}." >&2
  exit 1
}

echo "[info] Bind IP     : $BIND_IP"
echo "[info] Interface   : $IFACE"
echo "[info] Subnet CIDR : $SUBNET_CIDR"
echo "[info] Export dir  : $EXPORT_DIR"

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

sudo tee -a "$EXPORTS_FILE" >/dev/null <<EOF
${EXPORT_DIR}  ${SUBNET_CIDR}(rw,sync,no_subtree_check,all_squash,anonuid=${ANON_UID},anongid=${ANON_GID})
EOF

# ---- Bind NFS to the provided IP only ----
NFS_DEFAULT="/etc/default/nfs-kernel-server"
if sudo grep -q '^RPCNFSDOPTS=' "$NFS_DEFAULT" 2>/dev/null; then
  sudo sed -i -E "s/^RPCNFSDOPTS=.*/RPCNFSDOPTS=\"--host ${BIND_IP}\"/" "$NFS_DEFAULT"
else
  sudo tee -a "$NFS_DEFAULT" >/dev/null <<EOF
RPCNFSDOPTS="--host ${BIND_IP}"
EOF
fi

# ---- Apply configuration ----
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# ---- Firewall hardening (UFW if active) ----
# Allow-first, then deny. (UFW is ordered; allow must appear before deny.)
if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -qi "Status: active"; then
  sudo ufw allow from "$SUBNET_CIDR" to any port 2049 proto tcp
  sudo ufw allow from "$SUBNET_CIDR" to any port 2049 proto udp
  sudo ufw allow from "$SUBNET_CIDR" to any port 111  proto tcp
  sudo ufw allow from "$SUBNET_CIDR" to any port 111  proto udp

  sudo ufw deny 2049/tcp
  sudo ufw deny 2049/udp
  sudo ufw deny 111/tcp
  sudo ufw deny 111/udp
fi

echo "[ok] NFS export secured and ready."
echo "     Mount from workers with:"
echo "     sudo mount -t nfs4 ${BIND_IP}:${EXPORT_DIR} /mnt/${VOLUME_NAME}"

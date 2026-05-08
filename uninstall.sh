#!/usr/bin/env bash
set -Eeuo pipefail

SET4="${SET4:-block4}"
SET6="${SET6:-block6}"

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Please run as root."
  exit 1
fi

echo "[INFO] Removing iptables rules..."
while iptables -C INPUT -m set --match-set "$SET4" src -j DROP 2>/dev/null; do
  iptables -D INPUT -m set --match-set "$SET4" src -j DROP || break
done

while ip6tables -C INPUT -m set --match-set "$SET6" src -j DROP 2>/dev/null; do
  ip6tables -D INPUT -m set --match-set "$SET6" src -j DROP || break
done

echo "[INFO] Destroying ipset sets..."
ipset destroy "$SET4" 2>/dev/null || true
ipset destroy "$SET6" 2>/dev/null || true

echo "[INFO] Disabling ipset restore service..."
systemctl disable ipset-restore >/dev/null 2>&1 || true
rm -f /etc/systemd/system/ipset-restore.service
systemctl daemon-reload >/dev/null 2>&1 || true

echo "[INFO] Saving current firewall state..."
if [ -d /etc/iptables ] || command -v netfilter-persistent >/dev/null 2>&1; then
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4
  ip6tables-save > /etc/iptables/rules.v6
  netfilter-persistent save >/dev/null 2>&1 || true
fi

echo "[OK] Uninstalled."

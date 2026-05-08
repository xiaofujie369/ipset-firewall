#!/usr/bin/env bash
set -Eeuo pipefail

# Koyun ipset firewall installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main/install.sh | bash
#
# Optional:
#   RAW_BASE="https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main" bash install.sh

REPO_RAW_DEFAULT="https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main"
RAW_BASE="${RAW_BASE:-$REPO_RAW_DEFAULT}"

SET4="${SET4:-block4}"
SET6="${SET6:-block6}"
IPSET_CONF="${IPSET_CONF:-/etc/ipset.conf}"

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Please run as root."
    exit 1
  fi
}

install_deps() {
  echo "[INFO] Installing dependencies..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y ipset iptables iptables-persistent netfilter-persistent curl ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y ipset iptables iptables-services curl ca-certificates || dnf install -y ipset iptables curl ca-certificates
  elif command -v yum >/dev/null 2>&1; then
    yum install -y ipset iptables iptables-services curl ca-certificates || yum install -y ipset iptables curl ca-certificates
  else
    echo "[ERROR] Unsupported system. Please install ipset, iptables, curl manually."
    exit 1
  fi
}

backup_rules() {
  mkdir -p /root/firewall-backups
  local ts
  ts="$(date +%F-%H%M%S)"
  iptables-save > "/root/firewall-backups/iptables-${ts}.rules" || true
  ip6tables-save > "/root/firewall-backups/ip6tables-${ts}.rules" || true
  ipset save > "/root/firewall-backups/ipset-${ts}.conf" 2>/dev/null || true
  echo "[INFO] Backup saved to /root/firewall-backups/"
}

create_sets() {
  echo "[INFO] Creating ipset sets..."
  ipset create "$SET4" hash:net family inet hashsize 4096 maxelem 200000 -exist
  ipset create "$SET6" hash:net family inet6 hashsize 4096 maxelem 200000 -exist
}

load_blocklist() {
  echo "[INFO] Downloading blocklists from: $RAW_BASE"

  local tmp4 tmp6
  tmp4="$(mktemp)"
  tmp6="$(mktemp)"

  curl -fsSL "$RAW_BASE/blocklist/ipv4.txt" -o "$tmp4"
  curl -fsSL "$RAW_BASE/blocklist/ipv6.txt" -o "$tmp6"

  echo "[INFO] Loading IPv4 blocklist..."
  while IFS= read -r net; do
    net="${net%%#*}"
    net="$(echo "$net" | xargs)"
    [ -z "$net" ] && continue
    ipset add "$SET4" "$net" -exist
  done < "$tmp4"

  echo "[INFO] Loading IPv6 blocklist..."
  while IFS= read -r net; do
    net="${net%%#*}"
    net="$(echo "$net" | xargs)"
    [ -z "$net" ] && continue
    ipset add "$SET6" "$net" -exist
  done < "$tmp6"

  rm -f "$tmp4" "$tmp6"
}

apply_iptables() {
  echo "[INFO] Applying iptables rules..."

  iptables -C INPUT -m set --match-set "$SET4" src -j DROP 2>/dev/null \
    || iptables -I INPUT 1 -m set --match-set "$SET4" src -j DROP

  ip6tables -C INPUT -m set --match-set "$SET6" src -j DROP 2>/dev/null \
    || ip6tables -I INPUT 1 -m set --match-set "$SET6" src -j DROP
}

install_systemd_ipset_restore() {
  echo "[INFO] Installing ipset restore service..."

  cat > /etc/systemd/system/ipset-restore.service <<EOF
[Unit]
Description=Restore ipset rules
Before=netfilter-persistent.service iptables.service ip6tables.service
DefaultDependencies=no
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/sbin/ipset restore -exist -file $IPSET_CONF
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ipset-restore >/dev/null 2>&1 || true
}

save_rules() {
  echo "[INFO] Saving rules..."

  ipset save > "$IPSET_CONF"

  if [ -d /etc/iptables ] || command -v netfilter-persistent >/dev/null 2>&1; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
    systemctl enable netfilter-persistent >/dev/null 2>&1 || true
    netfilter-persistent save >/dev/null 2>&1 || true
  fi

  if command -v service >/dev/null 2>&1 && [ -d /etc/sysconfig ]; then
    service iptables save >/dev/null 2>&1 || true
    service ip6tables save >/dev/null 2>&1 || true
    systemctl enable iptables >/dev/null 2>&1 || true
    systemctl enable ip6tables >/dev/null 2>&1 || true
  fi
}

show_status() {
  echo
  echo "========== STATUS =========="
  echo "IPv4 set:"
  ipset list "$SET4" | grep -E "Name:|References:|Number of entries" || true
  echo
  echo "IPv6 set:"
  ipset list "$SET6" | grep -E "Name:|References:|Number of entries" || true
  echo
  echo "iptables:"
  iptables -L INPUT -n --line-numbers | head -10 || true
  echo
  echo "ip6tables:"
  ip6tables -L INPUT -n --line-numbers | head -10 || true
  echo "============================"
}

main() {
  need_root
  install_deps
  backup_rules
  create_sets
  load_blocklist
  apply_iptables
  install_systemd_ipset_restore
  save_rules
  show_status
  echo "[OK] Koyun ipset firewall installed."
}

main "$@"

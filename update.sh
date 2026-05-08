#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW_DEFAULT="https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main"
RAW_BASE="${RAW_BASE:-$REPO_RAW_DEFAULT}"

SET4="${SET4:-block4}"
SET6="${SET6:-block6}"
IPSET_CONF="${IPSET_CONF:-/etc/ipset.conf}"

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Please run as root."
  exit 1
fi

ipset create "$SET4" hash:net family inet hashsize 4096 maxelem 200000 -exist
ipset create "$SET6" hash:net family inet6 hashsize 4096 maxelem 200000 -exist

tmp4="$(mktemp)"
tmp6="$(mktemp)"
curl -fsSL "$RAW_BASE/blocklist/ipv4.txt" -o "$tmp4"
curl -fsSL "$RAW_BASE/blocklist/ipv6.txt" -o "$tmp6"

while IFS= read -r net; do
  net="${net%%#*}"
  net="$(echo "$net" | xargs)"
  [ -z "$net" ] && continue
  ipset add "$SET4" "$net" -exist
done < "$tmp4"

while IFS= read -r net; do
  net="${net%%#*}"
  net="$(echo "$net" | xargs)"
  [ -z "$net" ] && continue
  ipset add "$SET6" "$net" -exist
done < "$tmp6"

rm -f "$tmp4" "$tmp6"

iptables -C INPUT -m set --match-set "$SET4" src -j DROP 2>/dev/null \
  || iptables -I INPUT 1 -m set --match-set "$SET4" src -j DROP

ip6tables -C INPUT -m set --match-set "$SET6" src -j DROP 2>/dev/null \
  || ip6tables -I INPUT 1 -m set --match-set "$SET6" src -j DROP

ipset save > "$IPSET_CONF"

if [ -d /etc/iptables ] || command -v netfilter-persistent >/dev/null 2>&1; then
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4
  ip6tables-save > /etc/iptables/rules.v6
  netfilter-persistent save >/dev/null 2>&1 || true
fi

echo "[OK] Updated blocklist."
ipset list "$SET4" | grep "Number of entries" || true
ipset list "$SET6" | grep "Number of entries" || true

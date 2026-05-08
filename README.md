一键安装 / 更新命令
# 首次安装
curl -fsSL https://raw.githubusercontent.com/xiaofujie369/ipset-firewall/main/install.sh | bash

# 后续更新黑名单
curl -fsSL https://raw.githubusercontent.com/xiaofujie369/ipset-firewall/main/update.sh | bash

# 卸载防火墙黑名单
curl -fsSL https://raw.githubusercontent.com/xiaofujie369/ipset-firewall/main/uninstall.sh | bash
检查是否生效
echo "=== ipset ==="
ipset list block4 | grep -E "References|Number of entries"
ipset list block6 | grep -E "References|Number of entries"

echo
echo "=== iptables ==="
iptables -L INPUT -n --line-numbers | head -20
ip6tables -L INPUT -n --line-numbers | head -20

echo
echo "=== enabled ==="
systemctl is-enabled ipset-restore
systemctl is-enabled netfilter-persistent
正常结果参考
References: 1
Number of entries: 427

References: 1
Number of entries: 5

DROP       0    --  0.0.0.0/0            0.0.0.0/0            match-set block4 src
DROP       0    --  ::/0                 ::/0                 match-set block6 src

enabled
enabled

# Koyun ipset Firewall

把大量 `iptables -A INPUT -s IP段 -j DROP` 规则升级成 `ipset + iptables`。

## 当前黑名单数量

- IPv4: 427
- IPv6: 5

## 项目结构

```text
koyun-ipset-firewall/
├── install.sh
├── update.sh
├── uninstall.sh
└── blocklist/
    ├── ipv4.txt
    └── ipv6.txt
```

## 部署方式

### 1. 上传到 GitHub

创建一个仓库，例如：

```text
koyun-ipset-firewall
```

把本项目全部上传到仓库。

### 2. 修改脚本里的 GitHub 用户名

把下面文件里的：

```text
YOUR_GITHUB_USER
```

替换成你的 GitHub 用户名：

```text
install.sh
update.sh
```

例如你的 GitHub 用户名是 `koyun520`，仓库名是 `koyun-ipset-firewall`，那么 RAW 地址就是：

```text
https://raw.githubusercontent.com/koyun520/koyun-ipset-firewall/main
```

### 3. 每台 VPS 一行命令安装

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main/install.sh | bash
```

或者不修改脚本，直接这样运行：

```bash
RAW_BASE="https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main" bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main/install.sh)
```

## 更新黑名单

以后你只需要改 GitHub 里的：

```text
blocklist/ipv4.txt
blocklist/ipv6.txt
```

然后每台机器执行：

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main/update.sh | bash
```

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USER/koyun-ipset-firewall/main/uninstall.sh | bash
```

## 常用检查命令

```bash
ipset list block4 | grep -E "References|Number of entries"
ipset list block6 | grep -E "References|Number of entries"

iptables -L INPUT -n -v --line-numbers | head -20
ip6tables -L INPUT -n -v --line-numbers | head -20

systemctl is-enabled ipset-restore
systemctl is-enabled netfilter-persistent
```

## 新增黑名单

IPv4：

```bash
echo "1.2.3.0/24" >> blocklist/ipv4.txt
```

IPv6：

```bash
echo "240e:xxxx::/64" >> blocklist/ipv6.txt
```

提交到 GitHub 后，在 VPS 执行 update.sh 即可。

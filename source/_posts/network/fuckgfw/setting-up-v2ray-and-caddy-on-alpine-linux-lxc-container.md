---
title: 在 Alpine Linux 上使用 LXC 容器搭建 V2Ray 和 Caddy 服务，提供基于 IPv6 的 SSL WebSocket 代理
tags:
  - caddy2
  - linux
  - lxc
  - alpine
  - SSL
  - ipv6
  - websocket
  - proxy
  - Linux
published: true
hideInList: false
isTop: false
categories:
  - network
  - fuckgfw
date: 2024-07-03 15:32:41
feature:
---
### 前言

在现代互联网环境中，代理服务变得越来越重要，特别是在需要突破地域限制和提升隐私保护的时候。本文将详细介绍如何在 Alpine Linux 3.19 操作系统的 LXC 容器上，使用 V2Ray 和 Caddy 来搭建一个通过 IPv6 和域名提供的 SSL WebSocket 代理服务。

### 环境准备

1. **确保你的 LXC 容器运行并已分配 IPv6 地址**。
2. **确保你的域名已解析到你的 LXC 容器的 IPv6 地址**。

<!-- more -->

### 步骤 1：安装和配置 V2Ray

#### 1.1 进入你的 LXC 容器

```bash
lxc exec <your-container-name> /bin/ash
```

#### 1.2 安装必要的软件包

```bash
apk update
apk add curl unzip
```

#### 1.3 下载并安装 V2Ray

```bash
mkdir -p /root/TOOLS/v2ray
cd /root/TOOLS/v2ray
curl -L -o v2ray.zip https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
unzip v2ray.zip -d /root/TOOLS/v2ray
mv /root/TOOLS/v2ray/v2ray /root/TOOLS/v2ray/v2ray_bin
mv /root/TOOLS/v2ray/v2ctl /root/TOOLS/v2ray/v2ctl_bin
chmod +x /root/TOOLS/v2ray/v2ray_bin
chmod +x /root/TOOLS/v2ray/v2ctl_bin
```

#### 1.4 创建 V2Ray 配置文件

编辑 `/root/TOOLS/v2ray/config.json`，添加如下配置：

```json
{
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "your-uuid",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/your-websocket-path"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
```

注意：`your-uuid` 可以通过 `/root/TOOLS/v2ray/v2ctl_bin uuid` 生成，`your-websocket-path` 是 WebSocket 连接的路径，可以自定义。

#### 1.5 创建 V2Ray 服务文件

编辑 `/etc/init.d/v2ray`，添加如下内容：

```bash
#!/sbin/openrc-run

name="v2ray"
description="V2Ray Service"
command="/root/TOOLS/v2ray/v2ray_bin"
command_args="run -config /root/TOOLS/v2ray/config.json"
pidfile="/var/run/v2ray.pid"
```

#### 1.6 设置服务文件权限并启动 V2Ray

```bash
chmod +x /etc/init.d/v2ray
rc-update add v2ray default
service v2ray start
```

### 步骤 2：安装和配置 Caddy

#### 2.1 安装 Caddy

```bash
mkdir -p /root/TOOLS/caddy
wget -O /root/TOOLS/caddy/caddy 'https://caddyserver.com/api/download?os=linux&arch=amd64'
chmod +x /root/TOOLS/caddy/caddy
```

#### 2.2 创建 Caddyfile 配置文件

编辑 `/root/TOOLS/caddy/Caddyfile`，内容如下：

```caddyfile
abc.com {
    encode gzip
    tls your-email@example.com
    reverse_proxy /your-websocket-path localhost:10000 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Port {server_port}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

注意：`your-websocket-path` 应与 V2Ray 配置中的路径一致，`your-email@example.com` 用于自动获取 SSL 证书。

#### 2.3 创建 Caddy 服务文件

编辑 `/etc/init.d/caddy`，添加如下内容：

```bash
#!/sbin/openrc-run

name="caddy"
description="Caddy Web Server"
command="/root/TOOLS/caddy/caddy"
command_args="run --config /root/TOOLS/caddy/Caddyfile --adapter caddyfile"
pidfile="/var/run/caddy.pid"
```

#### 2.4 设置服务文件权限并启动 Caddy

```bash
chmod +x /etc/init.d/caddy
rc-update add caddy default
service caddy start
```

### 验证配置

#### 3.1 确保 V2Ray 和 Caddy 服务在运行

```bash
service v2ray status
service caddy status
```

#### 3.2 使用浏览器或 WebSocket 客户端测试 WebSocket 连接

```bash
wss://abc.com/your-websocket-path
```

### 常见问题排查

1. **查看 V2Ray 日志**：

    ```bash
    tail -f /var/log/v2ray/error.log
    ```

2. **查看 Caddy 日志**：

    ```bash
    tail -f /var/log/caddy/access.log
    ```

3. **手动启动 V2Ray 进行调试**：

    ```bash
    /root/TOOLS/v2ray/v2ray_bin run -config /root/TOOLS/v2ray/config.json
    ```

通过这些详细步骤，你应该能够成功在 Alpine Linux 3.19 的 LXC 容器上搭建 V2Ray 和 Caddy 服务，提供基于 IPv6 的 SSL WebSocket 代理服务。如果你在过程中遇到任何问题，欢迎在评论区留言讨论。
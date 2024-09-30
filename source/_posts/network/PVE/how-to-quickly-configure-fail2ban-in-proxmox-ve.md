---
title: '在Proxmox VE中快速设置Fail2ban防止多次登录失败的有效方法'
date: 2024-06-18 15:33:01
tags: [Linux,pve,Proxmox VE,fail2ban]
published: true
hideInList: false
feature: 
isTop: false
---
这里简要介绍了如何在Proxmox VE中设置Fail2ban以暂时阻止多次错误登录尝试的IP地址。

### 安装Fail2ban
在Proxmox VE主机上作为root执行以下命令：
```sh
apt update
apt install fail2ban
```

### 配置基础设置
建议使用`/etc/fail2ban/jail.local`文件，其设置优先于`jail.conf`。使用以下命令复制模板：
```sh
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

<!-- more -->

### 使用systemd后端设置Jail
在`/etc/fail2ban/jail.local`文件末尾添加：
```sh
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
backend = systemd
maxretry = 3
findtime = 2d
bantime = 1h
```

### 配置过滤器
创建文件`/etc/fail2ban/filter.d/proxmox.conf`并添加：
```sh
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
journalmatch = _SYSTEMD_UNIT=pvedaemon.service
```

### 启用配置
使用以下命令重启服务：
```sh
systemctl restart fail2ban
```

### 测试配置
尝试通过web界面使用错误的密码或用户名登录，然后使用以下命令测试配置：
```sh
fail2ban-regex systemd-journal /etc/fail2ban/filter.d/proxmox.conf
```

### 旧版选项：使用rsyslog后端
在`/etc/fail2ban/jail.local`文件末尾添加：
```sh
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 3
bantime = 1h
```

更多详细信息，请访问[Fail2ban Proxmox VE文档](https://pve.proxmox.com/wiki/Fail2ban)。
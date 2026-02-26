---
title: CentOS7 开机自动添加N2N的路由表
tags:
  - centos
  - route
  - n2n
  - edge
  - systemctl
  - linux
  - Linux
published: true
hideInList: false
isTop: false
categories:
  - network
  - n2n
date: 2022-02-06 19:50:38
feature:
---
# 1. 编辑 `systemctl` 自启动文件
```
vim /etc/systemd/system/n2route.service
```

<!-- more -->

```
[Unit]
Description=N2N Edge Add Route
After=edge.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 60
ExecStart=/usr/sbin/route -v add -net 192.168.100.0 netmask 255.255.252.0 gw 10.0.0.103
TimeoutStartSec=0
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

# 2. 重新加载 `systemctl`
```
systemctl daemon-reload
```

# 3. 手工运行命令测试
```
systemctl start n2route
```

# 4. 设置为开机自动启动
```
systemctl enable n2route
```
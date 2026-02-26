---
title: Proxmox VE 常用本地路径，以及如何修改hosts、主机名、IP地址和DNS配置
tags:
  - pve
  - Proxmox VE
  - hosts
  - ip
  - dns
  - network
  - iso
  - ovz
  - template
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-01-22 17:02:01
feature:
---
PVE本地ISO文件目录：`/var/lib/vz/template/iso`
PVE本地OVZ文件目录：`/var/lib/vz/template/cache`

<!-- more -->

# 修改hosts文件
* 重启后生效
```bash
vi /etc/hosts
```

# 修改主机名
* 重启后生效
```bash
vi /etc/hostname
```

# 修改IP地址和DNS配置
* 重启后生效
```bash
vi /etc/network/interfaces
```
参考的DNS配置
```bash
dns-nameservers 114.114.114.114,223.5.5.5
```
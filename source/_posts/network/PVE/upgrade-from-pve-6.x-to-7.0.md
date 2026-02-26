---
title: 如何从 Proxmox VE 6.4 升级到 Proxmox VE 7.0?
tags:
  - pve
  - upgrade
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-08-16 14:52:58
feature:
---
好久没关注 Proxmox VE 的官网。

直至前几天推荐 PVE  给同事使用时，才惊觉又升级大版本了。

作为升级强迫症患者，当然会选择立即升级到最新版本。

很早之前经历过从 PVE 5.x 升级到 6.0 的过程，现在又要开始 PVE 6.4 升级到 7.0。

总之，老老实实看官方教程就对了。

# 下面是各个 PVE 大版本升级的官方教程：

[Upgrade from Proxmox VE 6.x to 7.0](https://pve.proxmox.com/wiki/Upgrade_from_6.x_to_7.0)

[Upgrade from Proxmox VE 5.x to 6.0](https://pve.proxmox.com/wiki/Upgrade_from_5.x_to_6.0)

[Upgrade from Proxmox VE 4.x to 5.0](https://pve.proxmox.com/wiki/Upgrade_from_4.x_to_5.0)

[Upgrade from Proxmox VE 3.x to 4.0](https://pve.proxmox.com/wiki/Upgrade_from_3.x_to_4.0)

<!-- more -->

# 下面是这次版本升级过程的命令执行摘要，升级过程比较顺利
## 升级到当前 6.4 的最新版本
```bash
apt update -y && apt dist-upgrade -y
```

## 执行命令 `pve6to7` ，检查是否存在影响版本升级的问题
```bash
pve6to7
```
我检查了下，没有`FAILURES`，只有几个`WARNINGS`，问题不大，继续升级

## 检查 Linux Network Bridge Mac
官网有这个检查，我看了半天，没用到这个特性，家里的 PVE 使用的是固定 IP，没有任何影响，跳过

## 开始设置升级源
建议先提前备份配置文件
```bash
cp /etc/apt/sources.list /etc/apt/sources.list_bak
cp /etc/apt/sources.list.d/pve-install-repo.list /etc/apt/sources.list.d/pve-install-repo.list_bak 
sed -i 's/buster\/updates/bullseye-security/g;s/buster/bullseye/g' /etc/apt/sources.list
sed -i -e 's/buster/bullseye/g' /etc/apt/sources.list.d/pve-install-repo.list 
```

## 正式开始升级
```bash
apt update
apt dist-upgrade
```
> 别执行完命令就跑了，中间升级过程中，好几个地方需要人工交互

> 如果看不懂交互内容，使用`一路回车法`即可，反正我就靠的这方法

## 如果没报错，恭喜了，重启即可
## 如果报错了，解决报错的问题，再继续执行`apt dist-upgrade`，会从报错的地方继续执行
## 如果在安装过程中出现报错
`『W: (pve-apt-hook) You are attempting to remove the meta-package 'proxmox-ve'!』`
1. 改回原来 PVE 6.x 的 apt 配置文件
2. 打开我之前的教程[『Proxmox VE 6.3 日常维护，去掉未订阅的提示，和设置国内源』](https://blog.margrop.net/post/proxmox-ve-daily-maintain/)，
3. 查看里面的`如果更新时出现错误 You are attempting to remove the meta-package 'proxmox-ve'`小节，解决这个问题
3. 重新开始这个教程，建议按官方文档，会比我更加详细
 




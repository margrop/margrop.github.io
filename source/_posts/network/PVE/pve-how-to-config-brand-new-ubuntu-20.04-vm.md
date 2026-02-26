---
title: PVE下如何配置新安装的 ubuntu 20.04 server 虚拟机
tags:
  - pve
  - Proxmox VE
  - ubuntu
  - server
  - 虚拟机
  - vm
  - aliyun
  - 阿里云
  - 阿里源
  - ssh
  - qemu-guest-agent
  - mirror
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-01-30 15:33:44
feature:
---
# 下载安装镜像ISO
[阿里云ubuntu-20.04-live-server下载](https://mirrors.aliyun.com/ubuntu-releases/focal/ubuntu-20.04.2-live-server-amd64.iso)
[阿里云ubuntu-18.04-live-server下载](https://mirrors.aliyun.com/ubuntu-releases/bionic/ubuntu-18.04.5-live-server-amd64.iso)

<!-- more -->

# 新建虚拟机
* 略

# 插入ISO镜像，安装系统
* 略

# 修改apt-get为aliyun源：
* 用你熟悉的编辑器打开`/etc/apt/sources.list`，编辑为下面的内容
* 非20.04版本内容请访问[`阿里云 - Ubuntu 镜像`](https://developer.aliyun.com/mirror/ubuntu?spm=a2c6h.13651102.0.0.3e221b11WgXtYw)，查看更多内容
```bash
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
```

# 安装基本网络工具
```bash
sudo apt install net-tools
```

# 修改root密码为vm
输入 sudo passwd 命令，然后会提示输入当前用户的密码。
按enter键，终端会提示输入新的密码并确认，此时的密码就是新的root密码。
修改完毕以后，在执行su root命令，此时输入新的root密码即可。

# 新增SSH免密登录
```bash
cd ~
mkdir .ssh
echo ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyq1pB5aF0w6ps4OzwQl1C8uP41Iq7J+gqylLMXkoESrTUVhH1+irHuImxi2At886sO7x9s+b4jhRZoJZpZURPU4UmzUEBHKoXlqOf9eO//GtUita2AaPFw5tc0YgLPrgnO+z5MKfjo20aoJtVBvleRA/0YJcWy1a6ufXa8944D8a1Dirc9uVNR5QjKVFRbQt/twLkLdFB6t16HCwISKCVI56DcJOoY2g7mXI8clKaESeB+ANIhSKJclPwjoC6P0pHFfgqNauxC+0xugx3W2ZSIkVhdZu1L7iKvzXXPiETjPQA6qMjp/1dY2WU49Lf+wDOQplCy4HLq7QqNNVSzIBGw== Administrator@PCOS-1407251925 >> ~/.ssh/authorized_keys
```

# SSH启用允许root远程连接：
```bash
sudo vim /etc/ssh/sshd_config
```
* 将`PermitRootLogin`这一项取消注释，并改为`yes`
```bash
#LoginGraceTime 2m
#PermitRootLogin prohibit-password
PermitRootLogin yes
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10
```

# 安装qemu-guest-agent
* 参考<https://pve.proxmox.com/wiki/Qemu-guest-agent>
```bash
apt-get install qemu-guest-agent
```

# 参考
<https://developer.aliyun.com/mirror/ubuntu?spm=a2c6h.13651102.0.0.3e221b11WgXtYw>
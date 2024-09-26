---
title: 'ProxmoxVE 6.3 使用命令备份群晖虚拟机'
date: 2021-01-21 18:16:22
tags: [pve,Proxmox VE,dsm,backup,bash,sata]
published: true
hideInList: false
feature: 
isTop: false
---
由于我`ProxmoxVE`里面的群晖虚拟机，是使用`LUN直通`硬盘的方式运行的，所以没办法直接在`Web`界面上直接点击备份。
* DSM虚拟机备份的流程：
停止虚拟机 -> 解除挂载硬盘 -> 备份虚拟机 -> 挂载硬盘 -> 启动虚拟机

<!-- more -->

按这5个流程在`Web`界面上操作实在是麻烦，而且容易出错。
于是自己研究了一下`命令行`操作办法。

请自行修改下面的`虚拟机号`，`IP地址`，`SATA号`，`备份地址`，`硬盘ID`

# 连接至DSM
```bash
ssh root@192.168.xxx.xxx
```

# 关闭DSM
```bash
shutdown -h now
```

# 连接至PVE
```bash
ssh root@192.168.xxx.xxx
```

# 解除挂载硬盘
> 参考：<https://pve.proxmox.com/pve-docs/qm.1.html>
```bash
qm set 1000 -delete sata3
qm set 1000 -delete sata4
```

# 进行备份操作
> 参考：<https://pve.proxmox.com/wiki/Backup_and_Restore>
```bash
vzdump 1000 --dumpdir /mnt/pve/dsm20-iso/dump --mode snapshot --compress zstd
```

# 挂载硬盘
```bash
ls /dev/disk/by-id
qm set 1000 -sata3 /dev/disk/by-id/ata-ST8000DM004-2CX188_ZCT00CDM
qm set 1000 -sata4 /dev/disk/by-id/ata-WDC_WD80EZAZ-11TDBA0_2SG8LSRJ
```

# 启动虚拟机
```bash
qm start 1000
```
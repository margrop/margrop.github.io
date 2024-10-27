---
title: 'PVE对特定容器定时重启'
date: 2023-03-12 20:59:38
tags: [pro,pve,crontab,vm]
published: true
hideInList: false
feature: 
isTop: false
---
# 背景
* 由于观测到`HomeAssistant`这台`VM`的内存占用总是随着时间的推移而增加，然后最终会`OOM`，且无论升级了多少个版本也是如此，推测`HomeAssistant`有内存泄漏问题

# 解决方案
* 在虚拟机层面，对该`VM`进行定期重启（每天一次）
* 登录到`PVE`所在的服务器
* 执行`crontab -e`，并输入下面命令
```
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

0 12 * * * qm stop 2007 ; sleep 10 ; qm start 2007
```
* 注：命令中的`2007`是vmid，即`VM`的全局唯一ID

<!-- more -->
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTEyNjMyNTk4ODVdfQ==
-->
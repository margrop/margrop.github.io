---
title: Proxmox VE 环境下，如何安装集客AC虚拟机？
tags:
  - 集客
  - AC
  - pve
  - Proxmox VE
  - install
  - vhd
  - 虚拟机
  - AP
  - 漫游
  - 路由
  - 软路由
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-02-03 16:18:33
feature:
---
根据[恩山的集客AC AP扫盲贴](https://www.right.com.cn/forum/thread-1501038-1-1.html)介绍：
> 问：可以不用`AC`，直接两个`AP`连接主路由漫游么？
> 答：可以的，但有`AC`的漫游效果比没有好；有`ac`在，漫游效果不会差的，集客的漫游不是简单的弱踢。有`ac`在，不管集客`ap`支持不支持`kvr`，都有很好的效果，因为`ac+ap`是主动漫游，主动漫游走的不是`kvr`协议，对客户端要求也很低。微`ac`只负责下发配置，不能主动漫游，漫游效果依赖客户端。

<!-- more -->

# 集客AC简介
之前家里的好几台集客`AP`一直没有使用`AC`集中管理。
使用家庭环境的PVE后，可以无成本再添加一台集客`AC`的虚拟机，集中管理家里的各`AP`和各种无线设备，岂不妙哉。

下面是安装完成后的`AC`首页：
![](/post-images/jike-ac-index-1.jpg)

# 安装模式
建议使用`旁AC`的模式安装，这样`AC`只负责管理`AP`，至于什么外网接入，`DHCP`什么的，一律不负责。

# 下载AC x86固件
* 下载[vhd格式的安装包](https://www.lanzous.com/i9ccb1a)
* 访问[集客的官方蓝奏云地址](https://gecoos.lanzous.com/b01bcswyj)，下载最新版的升级包

# 导入虚拟机镜像
* 可参考之前的文章[在 Proxmox VE 里面，如何导入第三方的虚拟机镜像？](https://blog.margrop.net/post/pve-kvm-import-vm-format-qcow2/)

# 开机并安装集客AC
* 在`PVE`中打开虚拟机，连接虚拟机
* 等待成功启动后，安装的版本选择`3> AC控制器版`
* 安装完成后，在`PVE`的管理界面，关闭虚拟机，删除安装磁盘，点击“保存”，否则会重复安装过程。

# 参考文章
[黑群晖安装集客AC控制器简明教程（更新vhd格式蓝奏云下载）](https://www.right.com.cn/forum/thread-2101274-1-1.html)
[爱快软路由虚拟机安装集客网关AC控制器](https://post.smzdm.com/p/ag87mg6m/)

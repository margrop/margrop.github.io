---
title: 2021年的MacOS BigSur系统外接2k显示屏及字体虚化锯齿的解决方案整理
tags:
  - retina
  - MacOS
  - hidpi
  - monitor
published: true
hideInList: false
isTop: false
categories:
  - network
  - MacOS
date: 2022-01-25 21:45:33
feature:
---
# 1. 关闭系统 SIP

https://zhuanlan.zhihu.com/p/343151907

执行命令前需要关闭SIP（系统完整性保护），具体做法是：
进入恢复模式（开机时按住 command+R 键），在右上角打开系统终端，输入 csrutil disable（禁用）命令，在开启hidpi后可重新使用命令 csrutil enable （开启）。具体可参考，>>传送门

<!-- more -->

# 2. 启用HiDPI
关闭SIP后重启，在终端中执行如下命令

bash -c "$(curl -fsSL https://raw.githubusercontent.com/xzhih/one-key-hidpi/master/hidpi.sh)"

根据脚本的提示往下执行就行了。具体的操作请看大神的说明文档。 >>传送门

# 3. 安装 RDM
* RDM 下载地址
http://avi.alkalay.net/software/RDM/RDM-2.2.dmg

本站也提供`RDM`备份下载

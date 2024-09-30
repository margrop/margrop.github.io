---
title: '【转】黑群晖（Synology）半洗白最新方法'
date: 2021-01-19 18:10:53
tags: [dsm,docker,ddsm,synology,pat,序列号]
published: true
hideInList: false
feature: 
isTop: false
---
最近新搭一个`NAS`，安装好发现之前提供的半洗白方案已经不起作用了
之前的帖子<http://blog.lixx.vip/黑群晖（synology）nas-6-22-折腾记-半洗白/>
主要是群晖新版的`Docker 18.09.0-0506`关闭了`DDSM`安装

<!-- more -->

# 下载旧版Docker
* 旧版Docker下载地址（`Docker-x64-17.05.0-0401.spk`）：
<https://archive.synology.com/download/Package/Docker/17.05.0-0401>
* DDSM的PAT下载地址（`DSM_VirtualDSM_15284.pat`）：
<https://archive.synology.com/download/Os/DSM/6.1.7-15284>
也可以在[我的网盘](https://download.margrop.net/)下载

* 需在套件中心卸载新安装的`Docker`，然后安装下载的旧版

![](/post-images/ddsm1.jpg)

# 手动安装旧版Docker
* 浏览`Docker-x64-17.05.0-0401.spk`–下一步即可
* 然后新建容器，手动上传下载的PAT

![](/post-images/ddsm2.jpg)

* 连接，等5分钟左右初始化完成，打开记录序列号。

![](/post-images/ddsm3.jpg)
![](/post-images/ddsm4.jpg)

# 序列号替换到NAS里
* 替换方法可以看之前的帖子<http://blog.lixx.vip/黑群晖（synology）nas-6-22-折腾记-半洗白/>
`替换完成一定要重启`

![](/post-images/ddsm5.jpg)

# 测试效果
![](/post-images/ddsm6.jpg)
![](/post-images/ddsm7.jpg)

参考文章：
<http://blog.lixx.vip/黑群晖（Synology）半洗白最新方法/>
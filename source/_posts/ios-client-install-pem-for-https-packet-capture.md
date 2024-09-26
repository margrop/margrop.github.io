---
title: 'iOS端如何安装证书，如何https抓包'
date: 2021-01-28 15:33:23
tags: [ios,pem,cert,https,抓包,packet capture,charles,web,safari,描述文件]
published: true
hideInList: false
feature: 
isTop: false
---
# iOS下载证书
* 在Charles中导出pem证书，放置任意Web服务器中
* 下面是我自己使用的pem证书，仅作为示例，请不要安装。
![](/post-images/https_charles_1.png)

<!-- more -->

* 用iOS Safari打开URL，下载pem证书，iOS会提示是否下载描述文件，下载即可

![](/post-images/https_charles_2.jpg)
![](/post-images/https_charles_3.jpg)

# 安装描述文件
* `描述文件`安装完成后，打开iOS的`设置`，会看到多出一行，`已下载描述文件`。
* 选择刚下载的`Charles`的`描述文件`，点击右上角的`安装`
* 输入锁屏密码，然后再次点击右上角的`安装`，即可完成安装过程

![](/post-images/https_charles_4.jpg)

# 信任证书
* 再回到iOS的`设置` -> `通用` -> `关于本机` -> `证书设置`，启用`Charles`证书。

![](/post-images/https_charles_5.jpg)
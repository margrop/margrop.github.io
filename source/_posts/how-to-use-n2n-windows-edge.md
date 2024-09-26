---
title: '如何使用Windows运行N2N-运行篇'
date: 2021-01-29 13:43:19
tags: [n2n,edge,supernode,windows,nssm,tap-windows,ping,cmd,openssl]
published: true
hideInList: false
feature: 
isTop: false
---
这里只讲如何运行N2N的客户端edge，其实运行supernode起来更加简单，这里不再重复。

# 下载并解压N2N
> [一键打包下载](https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/n2n_20210129.zip)
> 含`edge`,`supernode`,`openssl链接库`(n2n运行必备),`tap-windows安装包`(n2n运行必备，Win7&Win10)

<!-- more -->

# 安装Tap-Windows
* 根据自己的平台，选择`Win10`或者`Win7`的安装文件，使用`一路回车法`安装即可。

# 试运行edge服务
* 下面以解压路径为`D:\TOOLS\`为例
* 进入命令行`CMD`，输入下面的命令
```
D:\TOOLS\n2n\edge -a 10.1.1.51 -c HTH -k V34oswnpfNZlIXhy -l blog.margrop.net:2345 -r -v -f
```
* 检查是否运行成功，同时打开另外一个`CMD`窗口，使用`ping`命令，如果能`ping`通同一个N2N的其他节点，edge节点就启动成功了。

# 将edge注册为系统服务
* 先关闭上面的edge服务
* 进入命令行`CMD`，输入下面的命令
```
cd D:\TOOLS\n2n\
nssm install edge
```
![](/post-images/windows-nssm-edge-1.png)

# 启动edge系统服务
* 进入管理员权限的命令行`CMD`，运行`net start edge`；
* 或者直接重启计算机，`edge`系统服务会自动开机启动。



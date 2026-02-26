---
title: Windows安装Frp客户端，可使用远程桌面
tags:
  - windows
  - frpc
  - frp
  - remote desktop
  - mstsc
  - nssm
  - client
published: true
hideInList: false
isTop: false
categories:
  - network
  - Windows
date: 2021-01-17 19:36:38
feature:
---
> 由于 TeamViewer 的使用限制越来越严格，时不时就会被当成企业用户，天下终究没有免费的午餐，下面是使用Frp客户端进行内网穿透，并可远程控制的方法。

> 请自行准备Frp服务器，以及考虑将3389端口暴露公网后的安全风险。

<!-- more -->

# 下载Frp客户端
<https://github.com/fatedier/frp/releases/download/v0.34.3/frp_0.34.3_windows_amd64.zip>

 
#配置Frp客户端
* 请自行修改`server_addr`、`server_port`、`remote_port`配置
```
[common]
server_addr = blog.margrop.net
server_port = 2345
 
[RDP-i5-TEST-CLIENT]
type = tcp
local_port = 3389
remote_port = 3333
```
 
# 设置自动启动
下载nssm，解压nssm到frp根目录。
<https://nssm.cc/release/nssm-2.24.zip>
 
运行 `nssm install frpc`
点击path选择frp相关目录，输入相关参数。点击`Install service`即可 安装为服务.如有安全软件阻挡,允许即可。在服务管理中查找frpc服务并启动。
 ![](/post-images/windows-nssm-frpc-1.png)

* 参数
```
d:\TOOLS\frp\frpc.exe
d:\TOOLS\frp\
-c d:\TOOLS\frp\frpc.ini
```
 
# 启动服务
```
net start frpc
```

# 设置本地用户密码
* 略

# 进入系统设置，开启允许远程控制
* 略
 
# 设置用户自动登录
1.   Windows+R打开运行，输入control userpasswords2敲回车。
2.  在弹出的用户账户窗口中，取消勾选。
3.  要使用本计算机，用户必须输入用户名和密码输入两次准备自动登录的账户密码
4.  完成之后，该账户即可无需密码自动登录
---
title: '天翼云电脑相关配置，及永不休眠方法'
date: 2024-06-04 12:27:39
tags: [ctyun,天翼云,云电脑]
published: true
hideInList: false
feature: 
isTop: false
---
Windows软件下载地址：https://download.margrop.net/#/EXE

> 天翼云电脑：https://desk.ctyun.cn/html/download/
> 计划软件：http://www.everauto.net/
> 天翼云电脑exe默认路径：C:\Program Files (x86)\CtyunClouddeskUniversal\CtyunClouddeskUniversal.exe
> 宝塔面板：https://www.bt.cn/new/product_windows.html
> 宝塔面板旧版本：http://download.bt.cn/win/update/net/BtSoft-Win.zip
> frp：https://github.com/fatedier/frp
> NSSM：http://www.nssm.cc/download
> Notepad++：https://download.margrop.net/d/oneindex/EXE/npp.8.6.7.Installer.x64.exe
> RustDesk：https://download.margrop.net/d/oneindex/EXE/rustdesk-1.2.3-2-x86_64.exe
<!-- more -->

下面的教程来自[https://www.4awl.net/3298.html](https://www.4awl.net/3298.html)

本期的主题是天翼云电脑永不休眠，加上一点点的内网穿透就能当服务器使用，拥有了一台云电脑还能当云服务器使用。

当然这个方案放在挂机宝或者其他云电脑产品上面也是可以使用的。

## 天翼云电脑不休眠

天翼云电脑如何不休眠，其实非常的简单，像一般的云电脑产品或者挂机宝等业务都是24小时开机，天翼云还是非常的有头脑，你超过一小时不用，我给你休眠既消耗你的服务器使用时间，还能保证我的资源回收完全利用。

这个时候我们当然必须要用魔法打败魔法啦，首先我们在我们的云电脑上面下载两个软件。

天翼云电脑：https://desk.ctyun.cn/html/download/ 和计划软件：http://www.everauto.net/

我们把两个软件都安装好，再打开天翼云电脑，把账号密码输入进去把自动登录和保存密码登录勾上。

现在目前天翼云电脑客户端采用了打开软件就自动打开云电脑的策略，这个时候我们再打开我们的计划软件去添加一个计划，打开云电脑，那么我们的云电脑就自动登录了我们的云电脑，一直挂着就实现了永不休眠的一个状态。

我们先添加一个新任务：

![天翼云电脑永不休眠 加上内网穿透当云服务器使用插图](https://www.4awl.net/wp-content/uploads/2024/04/2024040203380357.png)

任务类型我们选择程序-执行程序：

![天翼云电脑永不休眠 加上内网穿透当云服务器使用插图1](https://www.4awl.net/wp-content/uploads/2024/04/2024040203390078.png)

然后到程序路径填写：

C:\Program Files (x86)\CtyunClouddeskUniversal\CtyunClouddeskUniversal.exe

天翼云电脑默认的安装目录就是这个，如果大家自己更改了就根据实际情况修改。（注意这些操作都是在云电脑上完成的）

然后计划设定我们选择分钟循环，时间间隔设置50分钟就可以了，这个样子50分钟后我们的云电脑就会自动登录我们的云电脑，然后一直挂着就不会休眠了。

## 改造成云服务器

首先拿出我们的国民宝塔或者小皮面板都是可以的，这里我使用的是宝塔面板。

打开宝塔面板：https://www.bt.cn/new/product_windows.html 下载安装，会有一个打开面板的按钮，我们打开会发现无法访问，因为我们的IP不是公网IP，所以我们需要把IP修改成127.0.0.1就可以打开面板了。

打开面板先把环境软件都安装好，比如nginx mysql php等，这个样子我们的服务器就配置完成了，但是还需要访问公网绑定域名才算一个云服务器。

### frp内网穿透

frp 是一个专注于内网穿透的高性能的反向代理应用，支持 TCP、UDP、HTTP、HTTPS 等多种协议。可以将内网服务以安全、便捷的方式通过具有公网 IP 节点的中转暴露到公网。

如果我们没有公网IP服务器，那么我们可以去百度上面搜索一些公益frp服务然后搭建起来使用。

GitHub地址：https://github.com/fatedier/frp，可以在 [Release](https://www.4awl.net/go?_=702ef0b1ddaHR0cHM6Ly9naXRodWIuY29tL2ZhdGVkaWVyL2ZycC9yZWxlYXNlcw%3D%3D) 页面中下载到最新版本的客户端和服务端二进制文件，所有文件被打包在一个压缩包中。

首先我们需要下载Windows amd64 和 Linux amd64 的frp文件包，这个大家可以在GitHub上自己去下载。

把Linux的frp文件包上传到服务器上，并且解压出来，我们再执行 chmod +x frps 给他添加一个执行权限。然后使用下面的命令就能启动：

**nohup ./frps -c frps.** toml****  **&gt;**  /var/log/frp.**log** **2**> **&amp;** 1 **&amp;**

这个样子我们的frps就在后台启动完成了，注意：frps在有公网IP服务器上运行，frpc是在内网服务器上运行。

### Windows frpc配置+开机自启

首先，创建新建文本文件，里面内容如下，保存后将后缀改为vbs：

**set ws=WScript.** CreateObject **(** "WScript.Shell" **)**

**ws.** Run****  **&quot;c:frpfrpc.exe -c c:frpfrpc.toml&quot;** ,**0**

大家根据自己的frpc目录去修改然后创建一个vbs文件就可以了，再打开我们的控制面板，找到任务计划程序，创建计划任务：

![天翼云电脑永不休眠 加上内网穿透当云服务器使用插图2](https://www.4awl.net/wp-content/uploads/2024/04/2024040203591229.png)

1、在任务计划里面创建任务。
2、名字随意填写，勾选不管用户是否登录都运行。
3、触发器这栏，新建，选择启动时。
4、操作这栏，新建，程序和脚本这里选择刚才的创建vbs文件。
5、条件这栏，把只交流电源勾选去掉。
6、设置这栏，把运行超过3天停止任务勾选去掉

添加计划任务会需要输入管理员密码，默认天翼云电脑没有设置管理员密码，我们需要在系统-账户-登录选项 创建一个密码。

这个样子我们的开机启动就配置完成了，我们的云电脑就算重启也能保证frpc稳定运行。
<!--stackedit_data:
eyJoaXN0b3J5IjpbMzMyMjYwNDE3XX0=
-->
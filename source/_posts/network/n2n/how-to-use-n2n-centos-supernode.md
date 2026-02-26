---
title: 如何使用CentOS 7运行N2N—supernode篇
tags:
  - network
  - n2n
  - supernode
  - centos
published: true
hideInList: false
isTop: false
categories:
  - network
  - n2n
date: 2021-01-15 09:15:03
feature:
---
`超级节点（supernode）`：它允许边缘节点宣布和发现其他节点。它必须具有可在Internet上公开访问的端口。

<!-- more -->

# 先复习一下n2n的基本元素

> n2n是一款轻型VPN软件，可轻松创建绕过中间防火墙的虚拟网络。
> 为了开始使用n2n，需要两个元素：
> 
>  * `一个超级节点（supernode）`：它允许边缘节点宣布和发现其他节点。它必须具有可在Internet上公开访问的端口。
> 
>  * `边缘节点（node）`：将成为虚拟网络一部分的节点。
> n2n中的多个边缘节点之间共享的虚拟网络称为`社区（community）`。单个超级节点可以中继多个社区，并且一台计算机可以同时成为多个社区的一部分。边缘节点可以使用加密密钥对社区中的数据包进行加密。
> 
> n2n尝试在可能的情况下通过udp在边缘节点之间建立直接的`对等连接（p2p）`。如果不可能（通常是由于特殊的NAT设备），则超级节点也用于中继数据包。

![](/post-images/n2n_p1.jpg)
![](/post-images/n2n_p2.jpg)

# 已编译好的文件
> 编译环境：
> CentOS Linux release 7.9.2009 (Core)
> Linux version 3.10.0-1160.11.1.el7.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-44) (GCC) ) #1 SMP Fri Dec 18 16:34:56 UTC 2020

```bash
yum install openssl
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/CentOS7/supernode -O supernode
```

# 手工启动supernode

* 给予可执行权限
> 若直接下载的可执行文件，请自行copy到下面的路径

```bash
chmod +x /usr/local/sbin/supernode
```

* 测试是否能正常启动
> 提示：下面的`-l`参数，请根据需求，自行修改

```bash
/usr/local/sbin/supernode -l 2345 -v
```

* supernode参数简单解释，详情解释直接在命令行输入supernode

 参数名 | 英文                                                       | 中文 | 样例 
---- | ---|---- |---- 
-l | Set UDP main listen port to <port> | 设置UDP的主要监听端口 |  -l 2345
-v | Increase verbosity. Can be used multiple times | 启动verbose模式，打印更多的日志 |  -v

# 自动启动supernode

* 编辑systemctl的启动文件

```bash
vim /etc/systemd/system/supernode.service
```

```bash
[Unit]
Description=N2N SuperNode Run On Port 2012 UDP
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/supernode -l 2345
TimeoutStartSec=0

[Install]
WantedBy=default.target
```

* 启动服务

```bash
systemctl daemon-reload
systemctl stop supernode
systemctl start supernode
systemctl status supernode
```

* 设置为自动启动
```bash
systemctl enable supernode
```

#### 参考文献
1.[n2n实现内网穿透](https://www.jianshu.com/p/5021b70c3ff9)
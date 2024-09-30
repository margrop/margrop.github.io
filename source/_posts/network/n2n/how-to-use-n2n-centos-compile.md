---
title: '如何使用CentOS 7运行N2N—编译篇'
date: 2021-01-14 14:26:49
tags: [network,n2n]
published: true
hideInList: false
feature: 
isTop: false
---
若对完整编译过程有兴趣，可以慢慢浏览。
当然也可以直接下载下载已编译好的文件。

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
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/CentOS7/edge -O edge
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/CentOS7/supernode -O supernode
```

# 环境准备和开始编译

* 使用yum安装必要软件，下面是作者的参考文档

  > https://github.com/ntop/ntopng/blob/dev/doc/README.compilation

```bash
yum install -y openssl-devel cmake net-tools git gcc gcc-c++
```

* 从Github clone代码

当前最新版本是`2.8-stable`

```bash
cd ~
git clone https://github.com/ntop/n2n
cd n2n
git checkout 2.8-stable
```

* 开始编译

```bash
mkdir build
cd build
cmake .. 
make && make install
```
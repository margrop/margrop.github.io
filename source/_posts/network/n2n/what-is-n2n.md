---
title: 'N2N 是什么？'
date: 2021-01-13 16:27:39
tags: [network,n2n]
published: true
hideInList: false
feature: 
isTop: false
---
`N2N`是一个开源的P2P加密组网的工具

开源项目地址为：[https://github.com/ntop/n2n](https://github.com/ntop/n2n)

目前最新版本为`2.8-stable`

<!-- more -->

下面的介绍来自官网

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

# N2N可以支持哪些设备

目前N2N只提供了源代码，理论上只要是能编译运行的设备都可以支持。

但是iOS平台，目前还没开发者跟上，所以暂不支持。

其他的平台，比如 Windows、Linux、MacOS、OpenWRT、DSM等都可以支持的，当然需要自己编译。

在[下载中心](https://download.margrop.net)里，提供了这些Windows、CentOS 7、MacOS、DSM6.1已经编译好的文件，可以按需下载。
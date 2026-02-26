---
title: 如何使用Windows运行N2N-编译篇
tags:
  - network
  - n2n
  - windows
  - tap
  - tapwindows
published: true
hideInList: false
isTop: false
categories:
  - network
  - n2n
date: 2021-01-15 14:26:49
feature:
---
按照[N2N官方网站](https://github.com/ntop/n2n)的[Building说明](https://github.com/ntop/n2n/blob/dev/doc/Building.md)，Windows编译需要的软件有
`Visual Studio`,`Cmake`,`OpenSSL`。

看到`Visual Studio`我就头大，这个软件安装起来可不得了。
于是我选择了交叉编译，即使用Linux环境编译Windows的exe和dll文件。

<!-- more -->
# 已编译好的文件
> 编译环境：
> Ubuntu 20.04.1 LTS
> Linux vm-n2n-cc2 5.4.0-59-generic #65-Ubuntu SMP Thu Dec 10 12:01:51 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux

> [一键打包下载](https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/n2n_20210129.zip)
> 含`edge`,`supernode`,`openssl链接库`(n2n运行必备),`tap-windows安装包`(n2n运行必备，Win7&Win10)


```bash
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/edge.exe -O edge
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/supernode.exe -O supernode
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/libcrypto-1_1-x64.dll -O libcrypto-1_1-x64.dll
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/libssl-1_1-x64.dll -O libssl-1_1-x64.dll
```

# 准备编译环境
* 使用yum安装必要软件，下面是作者的参考文档
  
  > <https://github.com/ntop/ntopng/blob/dev/doc/README.compilation>
```bash
apt-get install mingw-w64
apt-get install cmake
apt-get install openssl
apt-get install libssl-dev
apt-get install build-essential git bison flex libxml2-dev libpcap-dev libtool libtool-bin rrdtool librrd-dev autoconf pkg-config automake autogen redis-server wget libsqlite3-dev libhiredis-dev libmaxminddb-dev libcurl4-openssl-dev libpango1.0-dev libcairo2-dev libnetfilter-queue-dev zlib1g-dev libssl-dev libcap-dev libnetfilter-conntrack-dev libreadline-dev libjson-c-dev libldap2-dev rename libsnmp-dev
```

# OpenSSL交叉编译
```bash
wget https://www.openssl.org/source/openssl-1.1.1i.tar.gz
tar -xvzf openssl-1.1.1i.tar.gz
cd openssl-1.1.1i
CROSS_COMPILE="x86_64-w64-mingw32-"  ./Configure mingw64 no-asm -shared --prefix=/opt/toolchain/openssl/install-x86_64
```

```bash
make
make install
```

# 下载N2N源代码
```bash
cd ~
git clone https://github.com/ntop/n2n
cd n2n
git checkout 2.8-stable
```

# N2N交叉编译准备
```bash
cd ~/n2n
vim toolChain.cmake
```
在`n2n`的目录下新建`toolChain.cmake`文件，并输入下面的配置内容
```bash
SET(CMAKE_SYSTEM_NAME Windows)
SET(CMAKE_CROSSCOMPILING TRUE)
SET(CMAKE_CROSSCOMPILER "x86_64-w64-mingw32-")
SET(CMAKE_C_COMPILER "${CMAKE_CROSSCOMPILER}gcc")
SET(CMAKE_CXX_COMPILER "${CMAKE_CROSSCOMPILER}g++")
SET(CMAKE_FIND_ROOT_PATH /opt/toolchain/openssl/install-x86_64)
SET(CMAKE_VERBOSE_MAKEFILE on)
```

# N2N交叉编译
使用`CMake`对`n2n`进行交叉编译
```bash
mkdir build
cd build
cmake -DCMAKE_TOOLCHAIN_FILE=../toolChain.cmake ..
make
```

# 安装TapWindows 9.24.2
[官方下载 For Win7](http://build.openvpn.net/downloads/releases/tap-windows-9.24.2-I601-Win7.exe)
[官方下载 For Win10](http://build.openvpn.net/downloads/releases/tap-windows-9.24.2-I601-Win10.exe)
[本站下载 For Win7](https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/tap-windows-9.24.2-I601-Win7.exe)
[本站下载 For Win10](https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/Windows/tap-windows-9.24.2-I601-Win10.exe)

# 可选，同一机器如何启动多个edge节点
* 访问Windows机器的Tap-Windows安装目录，默认为`C:\Program Files\TAP-Windows\bin`，该目录下面有个`addtap.bat`文件，反复执行这个`addtap.bat`文件，即可在Windowsv中添加多个虚拟网卡。在`网络和共享中心`里面的`更改适配器设置`里面可以看到多个虚拟网卡。
* 如果虚拟网卡太多了，也可以删除，进入`设备管理器` ，删除不需要的虚拟网卡即可。
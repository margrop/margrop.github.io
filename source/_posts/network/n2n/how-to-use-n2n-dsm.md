---
title: 如何使用群晖（DSM）运行N2N-编译篇
tags:
  - network
  - n2n
  - dsm
  - 群晖
  - nas
published: true
hideInList: false
isTop: false
categories:
  - network
  - n2n
date: 2021-01-15 13:18:07
feature:
---
群晖（后面使用`DSM`代替）是一个目前最著名的`NAS`系统，没有之一。
如何在`DSM`上直接运行`N2N`呢，当然又需要交叉编译了😂。
下面的交叉编译操作，需要有`Linux`的基本功，和`vim`操作的基本功。

<!-- more -->
# 已编译好的文件
> 编译环境：
> Ubuntu 20.04.1 LTS
> Linux vm-n2n-cc2 5.4.0-59-generic #65-Ubuntu SMP Thu Dec 10 12:01:51 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux

* 特别提示，`不同的DSM系统，不同的架构，文件是不能通用的`
* 下面是基于`DSM6.2.3`，`apollolake`架构编译好的文件
```bash
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.2.3/libssl.so.1.1 -O libssl.so.1.1 
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.2.3/libcrypto.so.1.1 -O libcrypto.so.1.1
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.2.3/edge -O edge
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.2.3/supernode -O supernode
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.2.3/renew -O renew
```

* 下面是基于`DSM6.1.7`，`broadwell`架构编译好的文件
```bash
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.1.7/libssl.so.1.1 -O libssl.so.1.1
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.1.7/libcrypto.so.1.1 -O libcrypto.so.1.1
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.1.7/edge -O edge
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/DSM6.1.7/supernode -O supernode
```

# N2N编译环境的准备 
* 使用`yum`安装必要软件，下面是作者的参考文档
  > <https://github.com/ntop/ntopng/blob/dev/doc/README.compilation>
  
# 交叉编译环境的准备 
首先去下载目标机器对应的`toolchain`(就是用来编译目标平台的程序的编译工具套装，`gcc`、`g++`、`ld`和库啥的)。

在[群晖的开发工具下载首页](https://sourceforge.net/projects/dsgpl/files/?source=navbar)，进入DMS相应版本的目录里，比如我的是6.2.3版本，进去最新的DSM 6.2 Tool Chains，然后可以看到有很多对应着不同处理器的压缩包，找和你CPU对应的版本。

可以通过`ls /sys/module | grep bios`下面的文件找到CPU平台的代号。

![](/post-images/n2n-dsm-compile.png)

可以看到我这台群晖对应的CPU平台为`apollolake`。

然后后面是Linux内核版本，和cpu架构，这两个可以通过`uname`命令查看。
```bash
uname -a
Linux Fluxworks_NAS 4.4.59+ #25426 SMP PREEMPT Wed Jul 8 03:21:29 CST 2020 x86_64 GNU/Linux synology_apollolake_918+
```
解压并添加环境变量：
```bash
tar -xf apollolake-gcc493_glibc220_linaro_x86_64-GPL.txz
# cd x86_64-pc-linux-gnu/bin
# ls
x86_64-pc-linux-gnu-addr2line  x86_64-pc-linux-gnu-cc            x86_64-pc-linux-gnu-elfedit    x86_64-pc-linux-gnu-gcc-ar      x86_64-pc-linux-gnu-gprof   x86_64-pc-linux-gnu-nm        x86_64-pc-linux-gnu-ranlib   x86_64-pc-linux-gnu-strip
x86_64-pc-linux-gnu-ar         x86_64-pc-linux-gnu-c++filt       x86_64-pc-linux-gnu-g++        x86_64-pc-linux-gnu-gcc-nm      x86_64-pc-linux-gnu-ld      x86_64-pc-linux-gnu-objcopy   x86_64-pc-linux-gnu-readelf
x86_64-pc-linux-gnu-as         x86_64-pc-linux-gnu-cpp           x86_64-pc-linux-gnu-gcc        x86_64-pc-linux-gnu-gcc-ranlib  x86_64-pc-linux-gnu-ld.bfd  x86_64-pc-linux-gnu-objdump   x86_64-pc-linux-gnu-size
x86_64-pc-linux-gnu-c++        x86_64-pc-linux-gnu-ct-ng.config  x86_64-pc-linux-gnu-gcc-4.9.3  x86_64-pc-linux-gnu-gcov        x86_64-pc-linux-gnu-ldd     x86_64-pc-linux-gnu-populate  x86_64-pc-linux-gnu-strings
```
可以看到`gcc`相关的可执行程序，这时候可以验证一下下的程序对不对，运行一个试试。
然后把`bin`目录添加到`PATH让系统能够找到你的工具链
```bash
export PATH=$PATH:你的工具包的目录/x86_64-pc-linux-gnu/bin
```

# OpenSSL交叉编译
下载并解压`OpenSSL`源代码
```bash
wget https://www.openssl.org/source/openssl-1.1.1i.tar.gz
tar -xvzf openssl-1.1.1i.tar.gz
cd openssl-1.1.1i
```
配置工具链地址，并生成`Makefile`文件
```bash
export PATH=$PATH:/root/dsm/x86_64-pc-linux-gnu/bin
./config no-asm -shared --prefix=/opt/toolchain/openssl/install-x86_64
```
在`Makefile`中搜索`:/CROSS_COMPILE=`，并在后面加上`x86_64-pc-linux-gnu-`
```bash
vim Makefile
:/CROSS_COMPILE=
x86_64-pc-linux-gnu-
```
删除2个`-m64`
```bash
:/-m64
```
开始交叉编译`OpenSSL`
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
SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_CROSSCOMPILING TRUE)
SET(CMAKE_CROSSCOMPILER "x86_64-pc-linux-gnu-")
SET(CMAKE_C_COMPILER "${CMAKE_CROSSCOMPILER}gcc")
SET(CMAKE_CXX_COMPILER "${CMAKE_CROSSCOMPILER}g++")
SET(CMAKE_FIND_ROOT_PATH /opt/toolchain/openssl/install-x86_64)
SET(CMAKE_VERBOSE_MAKEFILE on)
```
# N2N交叉编译
使用`CMake`对`n2n`进行交叉编译，
```bash
mkdir build
cd build
export PATH=$PATH:/root/dsm/x86_64-pc-linux-gnu/bin
cmake -DCMAKE_TOOLCHAIN_FILE=../toolChain.cmake ..
make
```
# N2N在群晖安装
用 `WinSCP`或`wget`之类的软件，将`edge`、`supernode`上传到 `/usr/bin`目录下
`libssl.so.1.1`和 `libcrypto.so.1.1`上传到 `/lib64` 下（32位CPU上传到 `/lib`下），其属性全改为 0755
```bash
chmod 755 edge
chmod 755 supernode
chmod 755 libssl.so.1.1
chmod 755 libcrypto.so.1.1
cp edge /usr/bin/
cp supernode /usr/bin/
cp libssl.so.1.1 /lib64/
cp libcrypto.so.1.1 /lib64/
```

手工启用tun模块：
```bash
insmod /lib/modules/tun.ko
```
* 可能会遇到的问题
> 我的白群也无意当中升级到了最新版本 dsm6.2.2，后来又降级到6.1.7，因为622启动edge以后，居然有一半的edge是ping不通的，即使使用了下面的方法仍然如此，而617全通，没有任何问题，可见617系统的网络功能更好一些。我无意当中发现群晖 dsm6.1、6.2（6.0未知）在启动之后，最开始的时候 n2n 是正常的，n2n的路由表也是有的，但是很快群晖就开始删除 n2n 的路由表了，这就是我们加入开机启动，刚开始 n2n 网络是可以 ping 通的，一会就断开了的原因。下面说说处理方法，2018-8-15 的方法仅做参考。将从 这里下载 （鼠标放上面，按鼠标右键，在弹出的菜单中选择“链接另存为...”）的文件保存为 renew，并加入开机启动 rc.rocal 文件里的 edge 语句后面： /etc/new/renew & （renew 的属性改为 0755）。这样，以后我们即使手动启动 n2n，它也会在 10 秒内给你加上群晖给删除的静态路由。

自动启用tun模块并启动edge：
```bash
cat <<EOF > /usr/local/etc/rc.d/tun.sh
!/bin/sh -e
insmod /lib/modules/tun.ko
sleep 30
/root/n2n/edge -d h0 -a 10.0.0.1 -c margrop -k UFDMIlrK3ueQz5mS -l blog.margrop.net:2345 -r -v -f &
#/etc/new/renew &
sleep 10
ifconfig h0 down
sleep 10
ifconfig h0 up
EOF
```
给脚本可执行权限：
```bash
chmod a+x /usr/local/etc/rc.d/tun.sh
```

# 参考文章
[http://www.lucktu.com/archives/778.html](交叉编译n2n，以openwrt为例子)
[群晖交叉编译记录（编译subversion）](https://www.cnblogs.com/oboth-zl/p/13447289.html)
[交叉编译N2N-LEDE Koolshare x86_64](https://blog.csdn.net/haoxia01/article/details/105506868)
[CMake交叉编译配置](https://blog.csdn.net/weicao1990/article/details/51149381)
[群晖(Synology)下N2N的设置方法](http://www.lucktu.com/archives/754.html)
---
title: 'gperftools安装与使用分析java堆外内存'
date: 2021-03-30 09:54:54
tags: [gperftools,perf,heap,dump,内存,jvm]
published: true
hideInList: false
feature: 
isTop: false
---
# CentOS
* 使用 yum 安装
```bash
yum install gperftools libunwind
```
* 可选，PDF 支持
```bash
yum install graphviz
```
* 设置环境变量
```bash
export LD_PRELOAD=/usr/lib64/libtcmalloc.so
export HEAPPROFILE=/DATA1/admin_tmp/gzip
```

<!-- more -->

* 启动 Java 程序
> 略
* 分析内存占用，文本显示结果
```bash
pprof --text /usr/bin/java /DATA1/admin_tmp/gzip.0001.heap
```
* 分析内存占用，PDF显示结果
```bash
```

# MacOS
* 使用 Brew 安装
```bash
brew install gperftools 或者 brew install --build-from-source gperftools
```
* 可选，PDF 支持
```bash
brew install graphviz 或者 brew install --build-from-source graphviz
```
* 设置环境变量
```bash
export DYLD_INSERT_LIBRARIES=/usr/local/Cellar/gperftools/2.8.1/lib/libtcmalloc.dylib
export HEAPPROFILE=/Users/cheng/tmp/test.log
```
* 启动 Java 程序
> 略
* 分析内存占用，文本显示结果
```bash
pprof --text /Library/Java/JavaVirtualMachines/jdk-11.0.10.jdk/Contents/Home/bin/java ~/tmp *.heap
```

* 分析内存占用，PDF显示结果
```bash
```

# 自行编译安装最新版本
```bash
mkdir ~/gperftools
cd gperftools
wget https://github.com/gperftools/gperftools/releases/download/gperftools-2.9.1/gperftools-2.9.1.zip
unzip gperftools-2.9.1.zip
cd gperftools-2.9.1

./configure
make
sudo make install
```


参考文章
<https://github.com/gperftools/gperftools/blob/master/INSTALL>
<https://blog.csdn.net/gao_yu_long/article/details/104459116>
<https://mp.weixin.qq.com/s/BWayrHM6b7lEt4A_ZS-D_Q>
<https://developer.ridgerun.com/wiki/index.php?title=Profiling_with_GPerfTools>
<http://www.dylan326.com/2017/09/28/gperftools/>
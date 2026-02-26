---
title: 使用KMS激活Win10，含第三方服务和自建服务
tags:
  - kms
  - activate
  - windows
  - slmgr
  - vlmcsd
  - gcc
  - firewall-cmd
  - 激活
published: true
hideInList: false
isTop: false
categories:
  - network
  - Windows
date: 2021-01-18 22:12:43
feature:
---
# 第三方服务激活
* 使用`管理员`权限，运行两行命令即可（鸣谢：<https://03k.org/kms.html>）
```bash
slmgr /skms kms.03k.org
slmgr /ato
```

<!-- more -->

# 自建服务激活
* 以 CentOS 7为例，含完整的下载代码、编译和安装过程
* 准备编译环境
```bash
yum install gcc git
```

* 下载源代码
```bash
cd ~/tools
mkdir win
cd win
git clone https://github.com/Wind4/vlmcsd.git
```

* 编译
```bash
cd vlmcsd
make
```

* 启动vlmcsd服务
```bash
cd bin
./vlmcsd  
ps aux|grep vlmcsd
```

* 防火墙开启1688端口
```bash
firewall-cmd --permanent --zone=public --add-port=1688/tcp
firewall-cmd --reload
```

* 搞定，回到文章开开头，把 `slgmr` 后面的域名，改为自己服务器的域名或IP地址即可


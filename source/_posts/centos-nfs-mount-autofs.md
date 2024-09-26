---
title: 'Centos 7.4 NFS自动挂载'
date: 2021-02-17 21:15:19
tags: [centos,nfs,autofs,mount]
published: true
hideInList: false
feature: 
isTop: false
---
# 触发式自动挂载
用户登录时自动挂载NFS共享目录`/home/share`到本机`/mnt/share`
```bash
yum install -y autofs
vi /etc/auto.master
/mnt /etc/auto.conf（这个配置文件本身就没有要自己创建）
vi /etc/auto.conf
share  192.168.1.22:/etc/letsencrypt/live/margrop.net-0001/（nfs服务器上共享文件）
service autofs restart 
```

<!-- more -->

重启服务
将虚拟机重启并且重启服务
```bash
service autofs restart      
cd /mnt
ls 
#此时看到不到share这个目录
```
自己在重新建立一个
```bash
mkdir -p /mnt/share
```
此时
```bash
cd /mnt
ls 
#会看到share这个目录
```
再继续`ls` 会看到共享文件
`df -h` 查看挂载信息

# 永久式自动挂载
```bash
vim /etc/fstab
192.168.65.10:/home/share  /mnt/share  nfs  defaults   0     0
```

参考文章
<https://juejin.cn/post/6857844360634236936>
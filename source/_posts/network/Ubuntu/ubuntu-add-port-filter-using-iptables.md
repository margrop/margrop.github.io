---
title: Ubuntu 22.04 通过ufw / iptables 开放指定端口——20230715更新
tags:
  - ubuntu
  - iptables
  - 防火墙
  - gfw
  - fuckgfw
published: true
hideInList: false
isTop: true
categories:
  - network
  - Ubuntu
date: 2023-02-26 20:04:53
feature:
---
# Ubuntu22.04 新增防火墙端口
## 查看防火墙状态
```
ufw status
```

## 开放22端口
```
ufw allow 22
```

## 添加完成，查看防火墙状态
```
ufw status
```

<!-- more -->

## 添加8888端口，并只接受TCP协议
```
ufw allow 8888/tcp
```

## 添加完成，查看防火墙状态
```
ufw status
```

## 查看防火墙状态编号列表的规则
```
ufw status numbered
```

## 删除编号 3 的规则
```
ufw delete 3
```

## 删除完成，重新查询状态编号列表的规则
```
ufw status numbered
```

***

# 弃用的方法：使用 iptables
一般情况下，ubuntu安装好的时候，iptables会被安装上，如果没有的话那就安装上吧

1.安装
在终端输入
```
sudo apt-get install iptables
```

2.添加规则
在终端输入
```
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
```
中间的`80`为所需要开放的端口

3.保存规则
在终端输入
```
iptables-save
```
完成上述命令我们就完成了开放指定的端口，但是如果此时服务器重启，上述规则就没有了，所以我们需要对规则进行一下持续化操作

4.持久化规则
<!-- more -->

这里我们需要在安装一下工具来帮我们实现，这里我们使用 `iptables-persistent` 

1)安装`iptables-persistent`
<!-- more -->

```
sudo apt-get install iptables-persistent
```
2)持久化规则
```
sudo netfilter-persistent save
sudo netfilter-persistent reload
```

完成上述操作就可以永久打开我们需要的端口了

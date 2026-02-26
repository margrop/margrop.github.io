---
title: 【转】iptables持久化方案
tags: []
published: true
hideInList: false
isTop: false
categories:
  - network
date: 2023-03-12 20:43:10
feature:
---
# debian若没有安装iptables，使用以下命令安装
```
apt-get install iptables
```
# 清除已有规则

```
iptables -F;iptables -X;iptables -Z
```
# 开放端口
### 允许本地回环接口(即运行本机访问本机) && 允许已建立的或相关连的通行
```
iptables -A INPUT -i lo -j ACCEPT;iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

<!-- more -->

### 允许所有本机向外的访问
```
iptables -A OUTPUT -j ACCEPT
```

### 转自<https://www.cnblogs.com/goldenstones/articles/8868577.html>

### 允许访问22端口
```
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

### 允许访问80端口
```
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

### 允许本地访问MySQL3306端口，禁止外部访问
```
iptables -A INPUT -p tcp -s 127.0.0.1 --dport 3306 -j ACCEPT;iptables -A INPUT -p tcp --dport 3306 -j DROP
```

### 允许FTP服务的21和20端口
```
iptables -A INPUT -p tcp --dport 21 -j ACCEPT;iptables -A INPUT -p tcp --dport 20 -j ACCEPT
```

### 允许安全宝监控的udp 161端口
```
iptables -I INPUT -p udp -s 60.195.252.107 --dport 161 -j ACCEPT;iptables -I INPUT -p udp -s 60.195.252.110 --dport 161 -j ACCEPT;iptables -I INPUT -p udp -s 127.0.0.1 --dport 161 -j ACCEPT;iptables -I INPUT -p udp -s 45.63.121.42 --dport 161 -j ACCEPT;iptables -I INPUT -p udp -s 192.168.1.2 --dport 161 -j ACCEPT
#如果有其他端口的话，规则也类似，稍微修改上述语句就行
```

### 允许ping
```
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
```

### 禁止其他未允许的规则访问（注意：如果22端口未加入允许规则，SSH链接会直接断开。）
```
iptables -A INPUT -j REJECT;iptables -A FORWARD -j REJECT
```

### 屏蔽单个IP的命令
```
iptables -I INPUT -s 123.45.6.7 -j DROP
```

### 封整个段即从123.0.0.1到123.255.255.254的命令
```
iptables -I INPUT -s 123.0.0.0/8 -j DROP
```

### 封IP段即从123.45.0.1到123.45.255.254的命令
```
iptables -I INPUT -s 124.45.0.0/16 -j DROP
```

### 封IP段即从123.45.6.1到123.45.6.254的命令
```
iptables -I INPUT -s 123.45.6.0/24 -j DROP
```

### 查看已添加的iptables规则
```
iptables -L -n
iptables -L -n --line-numbers
```

### 删除INPUT里序号为3的规则
```
iptables -D INPUT 3
```

### 临时保存规则
```
iptables-save
```

# 持久化保存
该命令保存的规则在系统重启后会失效，如何持久化保存？接着往下看
正常情况下，我们写入的iptables规则将会在系统重启时消失。即使我们使用iptables-save命令将iptables规则存储到文件，在系统重启后也需要执行iptables-restore操作来恢复原有规则。

iptables持久化方案，如何让防火墙规则重启后依旧有效？
推荐使用iptables-persistent工具：
### 首先，安装：
```
apt-get install iptables-persistent
```
### 保存当前设置的iptables防火墙规则
```
/etc/init.d/iptables-persistent save
或
netfilter-persistent save
```
### 重新载入防火墙规则
```
/etc/init.d/iptables-persistent reload
或
netfilter-persistent reload
```
* 说明：保存的规则文件路径如下
```
/etc/iptables/rules.v4
/etc/iptables/rules.v6
```
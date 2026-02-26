---
title: Docker容器内如何连接宿主机的MySQL服务器
tags:
  - docker
  - MySQL
published: true
hideInList: false
isTop: false
categories:
  - network
  - Container
date: 2021-09-30 13:08:50
feature:
---
博主最近遇到一种情况，从服务器拷贝了一份数据库在宿主机Mysql服务器上，想要用本地的数据库测试自己的代码正确性，但是项目程序都是靠docker一键部署的，于是必定要在docker容器里访问到本地的数据库。在探索中遇到了问题并得到了解决。

<!-- more -->

# 在docker容器里localhost并不是指宿主机的localhost
由此原因，并不能在容器中通过localhost:3306访问到宿主机的mysql

# docker在运行时就建立了虚拟网卡，并命名为docker0
我们可以在宿主机上运行ifconfig看到它，这就是宿主机建立的网桥，用于与各个容器之间通信

# 宿主机在与容器同一局域网的IP地址一般是docker0对应的IP地址段的首个地址（如172.0.17.1）
我们可以在容器里通过172.0.17.1:3306访问到宿主机的mysql服务器

# mysql服务器默认的设置为允许127.0.0.1段的ip地址访问
所以此时用172.0.17.1:3306仍然无法访问到宿主机
此时需要在设置一下mysql

```bash
mysql>GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '123456' WITH GRANT OPTION;
 mysql>flush privileges;
// 其中各字符的含义：
// *.* 对任意数据库任意表有效
// "root" "123456" 是数据库用户名和密码
// '%' 允许访问数据库的IP地址，%意思是任意IP，也可以指定IP
// flush privileges 刷新权限信息
```

# 参考文章
<https://www.jianshu.com/p/3e1fd311ba87>
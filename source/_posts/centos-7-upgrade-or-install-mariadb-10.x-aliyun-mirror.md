---
title: 'CentOS 7 升级或新安装MariaDB 10.5，使用阿里云镜像'
date: 2021-01-29 15:42:20
tags: [centos,mariadb,mysql,yum,install,upgrade,aliyun,阿里云,镜像,阿里源]
published: true
hideInList: false
feature: 
isTop: false
---
# 先进行系统更新
```bash
yum update -y
```

# 编辑yum配置文件，使用阿里云镜像
* 这里以 MariaDB 10.5为例
```bash
vim /etc/yum.repos.d/MariaDB10.repo

#http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = https://mirrors.aliyun.com/mariadb/yum/10.5/centos7-amd64
gpgkey = https://mirrors.aliyun.com/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck = 1
```

<!-- more -->

# 停止当前的MariaDB服务
```bash
systemctl stop mariadb
```

# 删除旧的MariaDB安装包
```bash
yum remove mariadb-server mariadb mariadb-libs
yum clean all
```

# 安装 MariaDB 10
```bash
yum install MariaDB-server MariaDB-client
```

# 启动并设置自动启动MariaDB
```bash
systemctl start mysql
systemctl enable mysql
```

# 升级旧 MariaDB 数据库
```bash
mysql_upgrade -uroot -p123456
```

# 检查是否安装成功
```bash
mysql --version
mysql -uroot -p123456
```

参考
[How to Upgrade MariaDB 5.5 to MariaDB 10.0 on CentOS 7](https://www.liquidweb.com/kb/how-to-upgrade-mariadb-5-5-to-mariadb-10-0-on-centos-7/)
[MariaDB 镜像](https://developer.aliyun.com/mirror/mariadb?spm=a2c6h.13651102.0.0.3e221b11UfYlwz)
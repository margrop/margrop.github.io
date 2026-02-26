---
title: CentOS 7 安装最新版本Node和NPM
tags:
  - centos
  - 安装
  - node
  - npm
  - 阿里云
  - 镜像
published: true
hideInList: false
isTop: false
categories:
  - network
  - CentOS
date: 2021-01-27 11:28:59
feature:
---
# 下载Node：
* 下载使用了阿里云镜像
```bash
mkdir ~/nodejs
cd ~/nodejs
wget https://npm.taobao.org/mirrors/node/latest-v15.x/node-v15.7.0-linux-x64.tar.gz
tar -xvzf node-v15.7.0-linux-x64.tar.gz
```


<!-- more -->


# 重命名为node
```bash
mv node-v15.7.0-linux-x64 node
```
# 配置环境变量
```bash
vim /etc/profile
```
* 在文件的最后添加
```bash
#set for nodejs  
export NODE_HOME=/root/nodejs/node  
export PATH=$NODE_HOME/bin:$PATH
```
* 保存退出后执行更新命令
```bash
source /etc/profile
```
如果不生效，重启系统就可以

# 检测node和npm是否安装成功
> 显示版本号则安装成功
```bash
# node -v
v8.0.0
# npm -v
5.0.0
```
> 注：现在 node 和 npm 还不能全局使用，需要做链接 （路径以自己实际情况为准）
```bash
ln -s /root/nodejs/node/bin/node /usr/local/bin/node 
ln -s /root/nodejs/node/bin/npm  /usr/local/bin/npm 
```
# 参考：
[Centos7:安装node和npm & npm配置全局路径](https://my.oschina.net/cqyj/blog/3016118)
[淘宝 NPM 镜像](https://developer.aliyun.com/mirror/NPM?spm=a2c6h.13651102.0.0.3e221b11cGmC53)
---
title: Mac OS X Lion 10 7 4 如何安装Homebrew
tags: []
published: true
hideInList: false
isTop: false
categories:
  - network
  - MacOS
date: 2021-05-29 17:30:33
feature:
---
参考文章：
* Mac OS X Lion 10 7 4 如何安装Homebrew
http://ocdman.github.io/2018/10/08/Mac-OS-X-Lion-10-7-4-%E5%A6%82%E4%BD%95%E5%AE%89%E8%A3%85Homebrew/
* 【macOS】brew安装
https://www.jianshu.com/p/1e5e72089a84

# 准备工作
* 需要手工编译安装`OpenSSL 1.1.1k`
* 需要手工编译安装`curl`最新版，注意编译时需要`OpenSSL`和`cacert.pem`证书
* 需要自行去 `http://git-scm.com/` 下载并安装最新版本的`git`

# 重要的特殊操作
```
mkdir -p /usr/local/opt/curl/bin
mkdir -p /usr/loca/opt/git/bin
ln -s /usr/local/bin/curl /usr/local/opt/curl/bin/curl
ln -s /usr/local/bin/git /usr/local/opt/git/bin/git

mv /usr/bin/curl /usr/bin/curl_bak
cp /usr/local/bin/curl /usr/bin/curl
```

<!-- more -->

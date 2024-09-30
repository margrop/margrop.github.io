---
title: '微信安装旧版本方法，版本过低，请升级最新版本'
date: 2021-03-05 11:22:11
tags: [wechat,adb,install,uninstall]
published: true
hideInList: false
feature: 
isTop: false
---
# 先安装最新版本微信，并登录。

# 使用cmd命令行保存用户数据方式卸载应用：
```bash
adb shell pm uninstall -k com.tencent.mm
```
# 重启手机
```bash
adb root
```
* 这一步非常重要，否则会出现错误提示`adb: failed to install xxxxxx Failure [INSTALL_FAILED_VERSION_DOWNGRADE]`
  
# 使用cmd命令安装旧版本apk(后面跟安装包路径)：
```bash
adb install -r -d
```
# 在旧版本上登录微信账号。

<!-- more -->

如果上面的方法不行，参照下面的方法
https://www.cnblogs.com/JOUO4/p/9976939.html
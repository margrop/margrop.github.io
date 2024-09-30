---
title: '【转】从 Authy 导出 TOTP token 的方法'
date: 2021-02-17 19:53:14
tags: [token,authy,golang,export,otp,totp]
published: true
hideInList: false
feature: 
isTop: false
---
基于 Ubuntu 18.04（普通用户），其他 Linux 系统大同小异。
Golang 官网：<https://golang.org/>
Github 仓库：<https://github.com/alexzorin/authy>

# 下载并安装 Golang（Mac系统，使用Brew）
```bash
brew install go
```

<!-- more -->

# 下载 Golang （Ubuntu系统）
> 由于 ubuntu apt 源中的 golang 版本为 1.10，无法运行用于导出 token 的应用，所以我们需要手动下载安装 golang 的最新版本。
> 如果已安装低版本 golang，请先提前卸载。

```bash
cd ~
wget https://dl.google.com/go/go1.14.linux-amd64.tar.gz
sudo tar -zxvf go1.14.linux-amd64.tar.gz -C /usr/local/bin
```
> 最新的下载链接可从 golang 官网获取。

# 设置环境变量（Ubuntu系统）
```bash
export GOPATH=~/go
export GOROOT=/usr/local/bin/go
export GOARCH=amd64
export GOOS=linux
export GOTOOLS=$GOROOT/pkg/tool
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
source /etc/profile
```

# 查看版本
```bash
go version
```
* 如显示为你所安装的版本，即安装成功。

# 导入仓库
```bash
#设置代理，请自行修改
export http_proxy=http://192.168.1.180:1081
export https_proxy=http://192.168.1.180:1081
#导入仓库
go get github.com/alexzorin/authy
```
> 由于国内网络原因，可能会无法下载，可启用 http/https 代理，具体此处不多作阐述。

# 导出 token
```bash
cd ~/go/src/github.com/alexzorin/authy/cmd/authy-export/
go run authy-export.go
```
* 根据提示输入你的 Aythy 账号信息：国家代码（中国为86）、手机号码、Authy APP 中授权、Authy 备份密码。
* 完成验证后，终端将展示你的 TOTP token（开头为：otpauth 的代码），保存后即可添加到其他客户端。


# 参考文章
<https://www.jianshu.com/p/5f37bdb6bc72>

---
title: 搭建自己的密码管理服务器 Bitwarden
tags:
  - bitwarden
  - 1password
  - docker
  - deploy
  - lastpass
  - openssl
  - letsencrypt
published: true
hideInList: false
isTop: false
categories:
  - network
  - Container
date: 2021-02-17 20:20:06
feature:
---
很多人对于把密码放在网上，比如 lastpass 虽然官方说是提供加密了，服务器上看不到用户密码，但是还是不太放心，那么就可以搭建开源的 Bitwarden 搭建一个自己的密码管理服务器。

> 准备：一个 vps 服务器和一个域名且解析 IP 地址到服务器


<!-- more -->


# 安装 Docker
## 1. 执行官方的安装脚本
```bash
wget -qO- get.docker.com | bash
```

## 2. 检查安装结果
```bash
docker version
```

## 3. 启动 Docker.
```bash
systemctl start docker
```

## 4. 查看 Docker 启动状态(绿色 active)
```bash
systemctl status docker
```

## 5. 允许 Docker 自启动
```bash
systemctl enable docker
```
 
# 安装 Bitwarden
* 快速开始
* 不进行自定义，不需要域名，快速搭建一个 Bitwarden 后端

## 1. 拉取 bitwarden_rs 镜像
```bash
docker pull bitwardenrs/server:latest
```

## 2. 运行容器
```bash
cd ~
mkdir bw-data
docker stop bitwarden
docker rm bitwarden
docker run -d --name bitwarden -v /root/bw-data/:/data/ -p 80:80 -p 443:443 bitwardenrs/server:latest
```

## 3. 打开防火墙的80端口
```bash
firewall-cmd --permanent --zone=public --add-port=80/tcp
firewall-cmd --permanent --zone=public --add-port=443/tcp
firewall-cmd --reload
```

# 自定义参数运行
> 自定义一些参数，加入 HTTPS 支持等。

## 1. 拉取 bitwarden_rs 镜像
```bash
docker pull bitwardenrs/server:latest
```

## 2. 生成一个 admin 用户管理页面的 token
```bash
openssl rand -base64 48
```

## 3. 生成 ssl 证书，以启用 https，推荐使用 acme.sh 免费申请及自动续签
### > 3.1 下载并执行 acme.sh 脚本
```bash
curl https://get.acme.sh | sh
```
### > 3.2 生成证书，这只是一种方式，其他方式可以自行搜索
```bash
apt install socat # debian 系为例
acme.sh –issue -d yourdomain.com –standalone
```
### > 3.3 将生成的证书拷贝安装到指定文件夹
```bash
acme.sh –installcert -d yourdomain.com \
–key-file /path/to/yourdomain.com.key \
–fullchain-file /path/to/fullchain.cer \
```

## 4. 运行 bitwarden_rs 容器
```bash
docker stop bitwarden
docker rm bitwarden
docker run -d --name bitwarden \
-e SIGNUPS_ALLOWED=false \
-e INVITATIONS_ALLOWED=false \
-e ADMIN_TOKEN={ADMIN_TOKEN} \
-e ROCKET_TLS='{certs="/ssl/fullchain.pem",key="/ssl/privkey.pem"}' \
-e DOMAIN=https://margrop.net \
-e DATA_FOLDER=/data/ \
-p 443:80 \
-v /root/bw-ssl:/ssl/ \
-v /root/bw-data:/data/ \
bitwardenrs/server:latest
docker logs --tail=100 bitwarden
```

* 参数解释：
```bash
SIGNUP_ALLOWED：是否允许注册
INVITATIONS_ALLOWED: 是否允许组织邀请注册
ADMIN_TOKEN：用户管理界面 (/admin)，可用于删除用户及邀请用户注册
ROCKET_TLS：ssl 证书信息，同时需要配置-v /path/to/host/ssl/:/path/to/docker/ssl/卷，前者为宿主机ssl证书的位置，后者为容器证书位置
DOMAIN：域名
LOG_FILE、LOG_LEVEL、EXTENDED_LOGGING：日志保存文件路径以及日志等级定义
DATA_FOLDER：docker容器数据保存文件夹（默认为 /data），除了定义这个文件夹之外，还可以定义附件、图标缓存、数据库等参数
DATABASE_URL：数据库路径
ATTACHMENT_FOLDER：附件路径
ICON_CACHE_FOLDER：图标缓存路径
```
以上是我自己觉得需要的一些配置，更多参数可参考官方 Wiki。

* 示例：
```bash
docker run -d –name bitwarden -e SIGNUPS_ALLOWED=false -e INVITATIONS_ALLOWED=false -e ADMIN_TOKEN=bTVsf7Hj99HPxECRPOL9U70bP0Iy5lXmbbJVP2tvwDszB8CClv+MD3TT6mSJTa4L -e ROCKET_TLS='{certs=”/ssl/bw.withdewhua.space/fullchain.cer”,key=”/ssl/bw.withdewhua.space/bw.withdewhua.space.key”}’ -e DOMAIN=https://bw.withdewhua.space -e LOG_FILE=/data/bitwarden.warn.log -e LOG_LEVEL=warn -e EXTENDED_LOGGING=true -p 443:80 -v /bw-data/:/data/ -v /usr/local/nginx/conf/ssl/:/ssl/ bitwardenrs/server:latest
```

# 容器操作命令
> $name 为 docker run 中定义的 name
## 启动容器
```bash
docker start $name
```

## 停止容器
```bash
docker stop $name
```

## 删除容器
```bash
docker rm $name
```

## 查看运行容器
```bash
docker ps -as
```

# 升级 Bitwarden 镜像
## 1. 重新拉取镜像
```
docker pull bitwardenrs/server:latest
```

## 2. 停止、删除原容器
```bash
docker stop bitwarden
docker rm bitwarden
```

# 3. 重新运行 docker run 命令

# 4. 查看镜像文件
```bash
docker image ls
```

# 5. 删除原镜像文件, $ID 在 step4 中可以看到
```bash
docker image rm $ID
```
 
# 客户端使用方法
* 使用方法就讲下Chrome插件的吧，其他的用法都是类似的。

打开插件，点击右上角设置按钮`bitwarden-chrome-extension`
填入 bitwarden 的域名`server-url`
保存后正常登录即可。

可以直接从 Bitwarden 官方导出然后导入到自己服务端，

> 这个 docker 镜像对于服务器的配置要求不高，内存在 512 就可以了。能用到的功能都有，包括最基本的密码保存、上传附件等，官方需要付费的 TOTP 、密码检测功能也都能直接使用的。 密码放在别人服务器上不放心的
> 可以自己搭建一个，或者搭建在自家的 nas 上也可以

参考文章
<https://www.jianshu.com/p/e432752a659d>
<https://hub.docker.com/r/bitwardenrs/server>
<https://github.com/dani-garcia/bitwarden_rs/wiki>
<https://host.bitwarden.in/deploying-and-using-of-bitwarden_rs/configuration>
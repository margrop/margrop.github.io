---
title: '群晖 Synology Docker Gitlab 套件更新'
date: 2021-08-23 17:30:14
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 警告
升级时会清空环境设置
这一点群晖有点。。。

# TIPS
基本上只要把
```
GITLAB_HTTPS=true
SSL_SELF_SIGNED=true
```
给加回来

再把端口号从`80`改为`443`即可

<!-- more -->

# 安装证书
gitlab 应用程序配置为查找 SSL 证书的默认路径是/home/git/data/certs，但是可以使用SSL_KEY_PATH、SSL_CERTIFICATE_PATH和SSL_DHPARAM_PATH配置选项更改。
```
chmod 400 /volumn1/docker/gitlab/gitlab/certs/gitlab.key
cp gitlab.key /volumn1/docker/gitlab/gitlab/certs/
cp gitlab.crt /volumn1/docker/gitlab/gitlab/certs/
cp dhparam.pem /volumn1/docker/gitlab/gitlab/certs/
chmod 400 /volumn1/docker/gitlab/gitlab/certs/gitlab.key
```

# 如何启用 HTTPS 支持
可以通过将GITLAB_HTTPS选项设置为 来启用 HTTPS 支持true。此外，在使用自签名 SSL 证书时，您还需要设置SSL_SELF_SIGNED选项true。假设我们使用自签名证书
```
docker run --name gitlab -d \
    --publish 10022:22 --publish 10080:80 --publish 10443:443 \
    --env ' GITLAB_SSH_PORT=10022 ' --env ' GITLAB_PORT=10443 ' \
    --env ' GITLAB_HTTPS=true ' --env ' SSL_SELF_SIGNED=true ' \
    --volume /srv/docker/gitlab/gitlab:/home/git/data \
    sameersbn/gitlab:14.1.3
```
在此配置中，任何通过普通 http 协议发出的请求都将自动重定向到使用 https 协议。但是，这在使用负载均衡时并不是最佳选择。


# 参考文章
<https://minazukisawa.blogspot.com/2019/07/synology-nas-docker-gitlab.html>
<https://www.simaek.com/archives/110/>
<https://github.com/sameersbn/docker-gitlab>
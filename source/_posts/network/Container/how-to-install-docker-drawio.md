---
title: '如何搭建开源的Web流程图工具 Diagrams.net（原draw.io）'
date: 2021-01-30 17:59:08
tags: [Diagrams.net,web,UML,drawio,ProcessOn,png,svg,html,xml,docker,firewall-cmd,github,draw,web,浏览器,画图,centos,draw,流程图]
published: true
hideInList: false
feature: 
isTop: false
---
`ProcessOn`目前已经是大家熟知的Web的`流程图`，`UML`等绘图工具了。但 `ProcessOn` 是收费服务，免费的又限制太多，那还有免费的午餐吗？

有，就是`Diagrams.net`。**完全免费，功能强大~**

<!-- more -->

# 在线使用`Diagrams.net`

`Diagrams.net`的使用方法非常简单，直接打开浏览器，输入网址 [draw.io](https:/draw.io)，或 [app.diagrams.net](https://app.diagrams.net/)，可以使用第三方存储，支持`Google Drive`，`OneDrive`，`Dropbox`，`Github`，`GitLab`，`本地文件`，`浏览器缓存`，保存的文件格式也有好多种，具体有『XML File(`.drawio`)』，『Editable Bitmap Image(`.png`)』，『Editable Vector Image(`.svg`)』，『HTML File(`.html)`』，『XML File(`.xml`)』，

如果不需要自己搭建 Diagrams.net 服务，那么这篇文章到这里已经结束了。

# 安装Docker环境
* 之前有写过[如何安装Docker](https://blog.margrop.net/post/centos-7-install-docker-ce-and-update-source/)，CentOS 7可以参考，其他OS建议参考[官方文档](https://docs.docker.com/engine/install/)

# 安装Docker-DrawIO
* Docker命令
```bash
docker run -it --name="draw" -p 8080:8080 -p 8443:8443 jgraph/drawio
docker start draw
```

* Docker开机自动启动镜像
```bash
docker update --restart=always draw
```

# 打开防火墙8080端口
```bash
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --reload
```

# 参考文章
[Install Docker Engine](https://docs.docker.com/engine/install/)
[Github : jgraph/docker-drawio](https://github.com/jgraph/docker-drawio)
[reboot 后 Docker服务及容器自动启动设置](https://blog.csdn.net/wxb880114/article/details/82904765)

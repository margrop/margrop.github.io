---
title: 'reboot 后 Docker服务及容器自动启动设置'
date: 2021-04-06 14:39:32
tags: [docker,reboot,container]
published: true
hideInList: false
feature: 
isTop: false
---
重启reboot操作系统后，发现docker 服务未启动，容器也未启动，天生反骨，怎么才能重启后自动启动呢？

# 解决问题两个问题：

1、docker服务自动重启设置
```bash
systemctl enable docker.service
```
![](https://img-blog.csdn.net/20180930084945717?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3d4Yjg4MDExNA==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

<!-- more -->
2、docker容器自动启动设置
```bash
docker ps -a
```
![](https://img-blog.csdn.net/20180930084754370?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3d4Yjg4MDExNA==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
使用一下命令对镜像从起： 
```bash
docker restart imageid
```
![](https://img-blog.csdn.net/20180930090040521?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3d4Yjg4MDExNA==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

在运行docker容器时可以加如下参数来保证每次docker服务重启后容器也自动重启：
```bash
docker run --restart=always
```
如果已经启动了则可以使用如下命令：
```bash
docker update --restart=always <CONTAINER ID>
```
![](https://img-blog.csdn.net/20180930090512846?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3d4Yjg4MDExNA==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
重启系统后
```bash
docker ps -a
```
![](https://img-blog.csdn.net/20180930090939534?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3d4Yjg4MDExNA==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)
----
# 参考文章
<https://blog.csdn.net/wxb880114/article/details/82904765>
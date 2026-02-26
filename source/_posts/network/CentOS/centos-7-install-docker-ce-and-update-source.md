---
title: CentOS 7 安装Docker并设置国内阿里源
tags:
  - centos
  - docker
  - install
  - aliyun
  - systemctl
  - 阿里云
  - 容器
published: true
hideInList: false
isTop: false
categories:
  - network
  - CentOS
date: 2021-01-29 11:40:18
feature:
---
# docker版本
docker从1.13版本之后采用时间线的方式作为版本号，分为社区版CE和企业版EE。Docker CE即社区免费版，Docker EE即企业版,付费使用。

<!-- more -->

# 卸载重装（可选）
```bash
sudo yum remove docker \
docker-client \
docker-client-latest \
docker-common \
docker-latest \
docker-latest-logrotate \
docker-logrotate \
docker-selinux \
docker-engine-selinux \
docker-engine
```

# 安装必备软件包
```bash
yum install -y yum-utils device-mapper-persistent-data lvm2
```
　　
# 添加阿里源信息
```bash
cd /etc/yum.repos.d
wget http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

# 查看可用docker版本
```bash
yum list docker-ce --showduplicates | sort -r
```
执行结果如下：
```bash
docker-ce.x86_64            3:20.10.2-3.el7                    docker-ce-stable
docker-ce.x86_64            3:20.10.2-3.el7                    @docker-ce-stable
docker-ce.x86_64            3:20.10.1-3.el7                    docker-ce-stable
docker-ce.x86_64            3:20.10.0-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.9-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.8-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.7-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.6-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.5-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.4-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.3-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.2-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.14-3.el7                   docker-ce-stable
docker-ce.x86_64            3:19.03.13-3.el7                   docker-ce-stable
docker-ce.x86_64            3:19.03.12-3.el7                   docker-ce-stable
docker-ce.x86_64            3:19.03.11-3.el7                   docker-ce-stable
docker-ce.x86_64            3:19.03.10-3.el7                   docker-ce-stable
docker-ce.x86_64            3:19.03.1-3.el7                    docker-ce-stable
docker-ce.x86_64            3:19.03.0-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.9-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.8-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.7-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.6-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.5-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.4-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.3-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.2-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.1-3.el7                    docker-ce-stable
docker-ce.x86_64            3:18.09.0-3.el7                    docker-ce-stable
docker-ce.x86_64            18.06.3.ce-3.el7                   docker-ce-stable
docker-ce.x86_64            18.06.2.ce-3.el7                   docker-ce-stable
docker-ce.x86_64            18.06.1.ce-3.el7                   docker-ce-stable
docker-ce.x86_64            18.06.0.ce-3.el7                   docker-ce-stable
docker-ce.x86_64            18.03.1.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            18.03.0.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.12.1.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.12.0.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.09.1.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.09.0.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.06.2.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.06.1.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.06.0.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.03.3.ce-1.el7                   docker-ce-stable
docker-ce.x86_64            17.03.2.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.03.1.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.03.0.ce-1.el7.centos            docker-ce-stable
Loading mirror speeds from cached hostfile
Loaded plugins: fastestmirror
Installed Packages
Available Packages
 * updates: mirrors.ustc.edu.cn
 * extras: mirrors.aliyun.com
 * base: mirrors.aliyun.com
```

# 安装docker
* 这里不是的最新版本，请根据上面命令列出的可用`Docker版本`进行安装
```bash
yum install docker-ce-18.03.1.ce-1.el7.centos
```
# 启动docker相关命令
```bash
//启动
systemctl start docker
//停止dcoker
systemctl stop docker
//设置开机启动
systemctl enable docker
//重启docker
systemctl restart docker
//查看docker
docker info
```

# 增加Docker阿里镜像源
可以通过修改`daemon`配置文件`/etc/docker/daemon.json`来使用加速器
下面代码中的`{ALIYUN_MIRROR}`，需访问[阿里云容器镜像服务](https://cr.console.aliyun.com/undefined/instances/mirrors)，登录阿里云账号即可看到。
```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://{ALIYUN_MIRROR}.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

参考文章
[阿里云centos安装docker](https://yq.aliyun.com/articles/700021)
[阿里云容器镜像服务](https://cr.console.aliyun.com/undefined/instances/mirrors)
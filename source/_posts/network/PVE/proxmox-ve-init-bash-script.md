---
title: Proxmox VE 安装完成后的初始化环境脚本
tags:
  - pve
  - Proxmox VE
  - install
  - bash
  - ssh
  - 镜像源
  - pvekclean
  - ntp
  - dns
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-01-22 16:42:46
feature:
---
个人为了方便安装PVE，自己整理的相关命令，请根据自己的环境自行修改。

<!-- more -->

# PVE免密登录
```bash
cd ~
mkdir .ssh
echo ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyq1pB5aF0w6ps4OzwQl1C8uP41Iq7J+gqylLMXkoESrTUVhH1+irHuImxi2At886sO7x9s+b4jhRZoJZpZURPU4UmzUEBHKoXlqOf9eO//GtUita2AaPFw5tc0YgLPrgnO+z5MKfjo20aoJtVBvleRA/0YJcWy1a6ufXa8944D8a1Dirc9uVNR5QjKVFRbQt/twLkLdFB6t16HCwISKCVI56DcJOoY2g7mXI8clKaESeB+ANIhSKJclPwjoC6P0pHFfgqNauxC+0xugx3W2ZSIkVhdZu1L7iKvzXXPiETjPQA6qMjp/1dY2WU49Lf+wDOQplCy4HLq7QqNNVSzIBGw== Administrator@PCOS-1407251925 >> ~/.ssh/authorized_keys
```

# 去掉未订阅的提示，最新8.0版本
```bash
sed -i_orig "s/data.status === 'Active'/true/g" /usr/share/pve-manager/js/pvemanagerlib.js
sed -i_orig "s/if (res === null || res === undefined || \!res || res/if(/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i_orig "s/.data.status.toLowerCase() !== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

# 配置DNS，解决无法上网的问题
* 新增阿里云的公共DNS
```bash
vi /etc/resolv.conf
:d9999
nameserver 223.5.5.5
nameserver 223.6.6.6
```

* 重启网络服务
```bash
service networking restart
```

# UI增加显示脚本
> 官网地址[pve_source - X86派 - 迷你硬件玩家集中地](https://bbs.x86pi.cn/thread?topicId=20 "pve_source - X86派 - 迷你硬件玩家集中地")

```yaml
#稳定版
wget -q -O /root/pve_source.tar.gz \
'https://bbs.x86pi.cn/file/topic/2023-11-28/file/01ac88d7d2b840cb88c15cb5e19d4305b2.gz' \
&& tar zxvf /root/pve_source.tar.gz && /root/./pve_source
```

# 如何设置国内源 - For PVE 6.x
* 设置 debian 阿里云源 - For PVE 6.x
```bash
cat > /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/debian/ buster main non-free contrib
deb http://mirrors.aliyun.com/debian/ buster-updates main non-free contrib
deb http://mirrors.aliyun.com/debian/ buster-backports main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ buster main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ buster-updates main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ buster-backports main non-free contrib
deb http://mirrors.aliyun.com/debian-security/ buster/updates main non-free contrib
deb-src http://mirrors.aliyun.com/debian-security/ buster/updates main non-free contrib
EOF
```
* 删除企业源 - For PVE 6.x
```bash
rm -rf /etc/apt/sources.list.d/pve-enterprise.list
rm -rf /etc/apt/sources.list.d/ceph.list
```
* 下载秘钥 - For PVE 6.x
```bash
wget http://mirrors.ustc.edu.cn/proxmox/debian/proxmox-ve-release-6.x.gpg -O /etc/apt/trusted.gpg.d/proxmox-ve-release-6.x.gpg
```
* 添加国内源 - For PVE 6.x
```bash
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/pve buster pve-no-subscription" >/etc/apt/sources.list.d/pve-install-repo.list
apt update -y && apt dist-upgrade -y
```

# 如何设置国内源 - For PVE 7.x
* 设置 debian 阿里云源 - For PVE 7.x
```bash
cat > /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/debian/ bullseye main non-free contrib
deb http://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib
deb http://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ bullseye main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ bullseye-updates main non-free contrib
deb-src http://mirrors.aliyun.com/debian/ bullseye-backports main non-free contrib
deb http://mirrors.aliyun.com/debian-security/ bullseye-security main non-free contrib
deb-src http://mirrors.aliyun.com/debian-security/ bullseye-security main non-free contrib
EOF
```
* 删除企业源 - For PVE 7.x
```bash
rm -rf /etc/apt/sources.list.d/pve-enterprise.list
```
* 下载秘钥 - For PVE 7.x
```bash
wget http://mirrors.ustc.edu.cn/proxmox/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
```
* 添加国内源 - For PVE 7.x
```bash
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/pve bullseye pve-no-subscription" >/etc/apt/sources.list.d/pve-install-repo.list
apt update -y && apt dist-upgrade -y
```

# 如何设置国内源 - For PVE 8.x
* 设置 debian 阿里云源 - For PVE 8.x
```bash
cat > /etc/apt/sources.list <<EOF
deb https://mirrors.huaweicloud.com/debian/ bookworm main non-free contrib
deb-src https://mirrors.huaweicloud.com/debian/ bookworm main non-free contrib
deb https://mirrors.huaweicloud.com/debian-security/ bookworm-security main
deb-src https://mirrors.huaweicloud.com/debian-security/ bookworm-security main
deb https://mirrors.huaweicloud.com/debian/ bookworm-updates main non-free contrib
deb-src https://mirrors.huaweicloud.com/debian/ bookworm-updates main non-free contrib
deb https://mirrors.huaweicloud.com/debian/ bookworm-backports main non-free contrib
deb-src https://mirrors.huaweicloud.com/debian/ bookworm-backports main non-free contrib
EOF
```
* 删除企业源 - For PVE 8.x
```bash
rm -rf /etc/apt/sources.list.d/pve-enterprise.list
rm -rf /etc/apt/sources.list.d/ceph.list
```
* 下载秘钥 - For PVE 8.x
```bash
wget http://mirrors.ustc.edu.cn/proxmox/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
```
* 添加国内源 - For PVE 8.x
```bash
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/pve bookworm pve-no-subscription" >/etc/apt/sources.list.d/pve-install-repo.list
apt update -y && apt dist-upgrade -y
```

# 更新PVE，并安装常用软件
```bash
apt-get update && apt-get install vim lrzsz unzip net-tools curl screen uuid-runtime git -y && apt dist-upgrade -y
```

# 安装pvekclean
```bash
git clone https://github.com/jordanhillis/pvekclean.git
cd pvekclean
chmod +x pvekclean.sh
./pvekclean.sh
```

# 安装并设置NTP服务 - For PVE 6.x
> 参考<https://pve.proxmox.com/wiki/Time_Synchronization>
* 新增阿里云的公共NTP地址
```bash
mv /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf_bak
echo [Time] >> /etc/systemd/timesyncd.conf
echo NTP=ntp1.aliyun.com ntp2.aliyun.com ntp3.aliyun.com ntp4.aliyun.com ntp5.aliyun.com ntp6.aliyun.com ntp7.aliyun.com >>    /etc/systemd/timesyncd.conf
cat /etc/systemd/timesyncd.conf
timedatectl set-ntp true 
timedatectl status
```

# 安装并设置NTP服务 - For PVE 7.x / 8.x
> 参考<https://help.aliyun.com/document_detail/187016.html?utm_content=g_1000230851&spm=5176.20966629.toubu.3.f2991ddcpxxvD1#title-ik2-31x-dso>
* 新增阿里云的公共NTP地址
```bash
vim /etc/chrony/chrony.conf
新增下面的server
# Aliyun NTP
server ntp1.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp2.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp3.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp4.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp5.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp6.aliyun.com minpoll 4 maxpoll 10 iburst
server ntp7.aliyun.com minpoll 4 maxpoll 10 iburst
```

# 如果更新时出现错误 E: Sub-process /usr/bin/dpkg returned an error code
> 参考<https://blog.csdn.net/yusiguyuan/article/details/24269129>
```bash
apt-get update --fix-missing
apt-get autoremove && sudo apt-get clean && sudo apt-get install -f
```

# 如果更新时出现错误 You are attempting to remove the meta-package 'proxmox-ve'
> 参考<https://forum.proxmox.com/threads/apt-get-dist-upgrade-wants-to-remove-proxmox-ve-pve-firmware.39360/>
```bash
#Yes, I've tested it. I can remove any kernels listed with this command:
#列出当前系统的Linux镜像
dpkg --list | egrep -i --color 'linux-image|linux-headers'
#Then:
#删除旧的Linux镜像
apt-get --purge remove linux-image-4.9.0-4-amd64 linux-image-4.9.0-5-amd64
#更新grub
update-grub
```

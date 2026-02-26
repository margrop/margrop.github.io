---
title: Proxmox VE 6.4 日常升级命令
tags:
  - Proxmox VE
  - pvekclean
  - 升级
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-03-29 08:23:52
feature:
---
# 移除未使用的Linux内核
```bash
pvekclean
```
# 更新软件：
```bash
apt update -y && apt dist-upgrade -y
```
# 去掉未订阅的提示，支持  PVE 6.3 / 6.4
```bash
sed -i_orig "s/data.status === 'Active'/true/g" /usr/share/pve-manager/js/pvemanagerlib.js
sed -i_orig "s/if (res === null || res === undefined || \!res || res/if(/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i_orig "s/.data.status.toLowerCase() !== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

<!-- more -->

# 确认无误后，重新启动服务器
```bash
reboot
```

# 解决软件升级问题
* 新增阿里云的Debian镜像源
```bash
mv /etc/apt/sources.list /etc/apt/sources.list.bak
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

* 新增Proxmox VE的中科大镜像源
```bash
# 删除企业源
rm -rf /etc/apt/sources.list.d/pve-enterprise.list
# 下载秘钥
wget http://mirrors.ustc.edu.cn/proxmox/debian/proxmox-ve-release-6.x.gpg -O /etc/apt/trusted.gpg.d/proxmox-ve-release-6.x.gpg
# 添加国内源
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/pve buster pve-no-subscription" >/etc/apt/sources.list.d/pve-install-repo.list
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

# 安装并设置NTP服务
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

# 如果更新时出现错误 E: Sub-process /usr/bin/dpkg returned an error code
> 参考<https://blog.csdn.net/yusiguyuan/article/details/24269129>
```bash
apt-get update --fix-missing
apt-get autoremove && sudo apt-get clean && sudo apt-get install -f
```

# 如果更新时出现错误 You are attempting to remove the meta-package 'proxmox-ve'
1. 首先检查 Proxmox VE 的企业源配置是否正确，企业源是否能正常访问
```bash
cat /etc/apt/sources.list.d/pve-enterprise.list
```
2. 如果企业源配置完全正确，再继续往下看
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

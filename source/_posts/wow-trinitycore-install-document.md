---
title: 'WOW TrinityCore 安装教程（基于10.0.2.47657）'
date: 2023-03-12 20:28:58
tags: [wow]
published: true
hideInList: false
feature: 
isTop: false
---
# WOW TrinityCore 安装教程
## 相关参考资料
* https://github.com/TrinityCore/TrinityCore
* https://trinitycore.info/en/home
* https://trinitycore.info/install/requirements/linux
* https://trinitycore.info/install/Core-Installation/linux-core-installation
* https://trinitycore.info/en/install/Server-Setup
* https://trinitycore.info/en/install/Final-Server-Steps

<!-- more -->

# 环境准备：Ubuntu20.04
## 修改apt-get为aliyun源：
```
https://developer.aliyun.com/mirror/ubuntu?spm=a2c6h.13651102.0.0.3e221b11KR1TWB
```

## 修改root密码：
输入 `sudo passwd` 命令，然后会提示输入当前用户的密码。
按Enter键，终端会提示输入新的密码并确认，此时的密码就是新的root密码。
修改完毕以后，在执行`su root`命令，此时输入新的root密码即可。

## SSH免密登录：
```
cd ~
mkdir .ssh
echo ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyq1pB5aF0w6ps4OzwQl1C8uP41Iq7J+gqylLMXkoESrTUVhH1+irHuImxi2At886sO7x9s+b4jhRZoJZpZURPU4UmzUEBHKoXlqOf9eO//GtUita2AaPFw5tc0YgLPrgnO+z5MKfjo20aoJtVBvleRA/0YJcWy1a6ufXa8944D8a1Dirc9uVNR5QjKVFRbQt/twLkLdFB6t16HCwISKCVI56DcJOoY2g7mXI8clKaESeB+ANIhSKJclPwjoC6P0pHFfgqNauxC+0xugx3W2ZSIkVhdZu1L7iKvzXXPiETjPQA6qMjp/1dY2WU49Lf+wDOQplCy4HLq7QqNNVSzIBGw== Administrator@PCOS-1407251925 >> ~/.ssh/authorized_keys
```

## SSH启用允许root远程连接：
```
sudo vim /etc/ssh/sshd_config
```

## 修改apt-get为huawei cloud源：
> https://mirrors.huaweicloud.com/home
```
sudo cp -a /etc/apt/sources.list /etc/apt/sources.list.bak

sudo sed -i "s@http://.*archive.ubuntu.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list
sudo sed -i "s@http://.*security.ubuntu.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list

sudo sed -i "s@http://mirrors.aliyun.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list
sudo sed -i "s@http://mirrors.aliyun.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list

sudo sed -i "s@http://mirrors.163.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list
sudo sed -i "s@http://mirrors.163.com@http://repo.huaweicloud.com@g" /etc/apt/sources.list
```

## 安装常用软件

```
apt install vim lrzsz p7zip unzip net-tools curl wget -y
```

## 安装常用网络工具
```
sudo apt install net-tools
```

## VM安装qemu-guest-agent：
<https://pve.proxmox.com/wiki/Qemu-guest-agent>
```
apt-get install qemu-guest-agent
```

## Ubuntu 常规更新
```
apt update && apt dist-upgrade
apt autoremove
fstrim
```

## Ubuntu逻辑分区扩容（非必须）
<https://cloud.tencent.com/developer/article/2134778>
```
#显示当前容量
vgdisplay
  --- Volume group ---
  VG Name               ubuntu-vg
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  2
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               1
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               <96.95 GiB
  PE Size               4.00 MiB
  Total PE              24818
  Alloc PE / Size       12409 / 48.47 GiB
  Free  PE / Size       12409 / 48.47 GiB
  VG UUID               0r0B09-AHil-bc9D-fXtF-o3Y3-MjZj-T10Sf9

#选择全部扩容
#扩展逻辑卷的逻辑边界
lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv

#使用resizefs2命令重新加载逻辑卷的大小才能生效
resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```



# 编译代码及处理数据
## 代码编译
```
cd ~/TrinityCore/build
mkdir -p /home/wow/server1002
cmake ../ -DCMAKE_INSTALL_PREFIX=/home/wow/server1002
make -j 6
```

## Linux挂载DSM共享磁盘（可选操作）
```
mkdir -p /home/dsm10/sg10t
mount -t cifs -o username=my,password=123456 //192.168.1.1/sg10t/ /home/dsm10/sg10t
```
## 复制脚本（可选操作）
```
cp /root/TrinityCore/contrib/extractor.sh /home/dsm10/sg10t/Game/Development/wow1002
cd /home/dsm10/sg10t/Game/Development/wow1002
```
## 执行地图等数据转换（自行修改Path路径）
```
#路径配置
ClientPath: /home/dsm10/sg10t/Game/Development/wow1002
ServerPath: /home/wow/server1002
#执行命令
screen
cd /home/dsm10/sg10t/Game/Development/wow1002
./extractor.sh
```
选择`4.Extract all`

# 创建数据库和数据表
```
#创建空数据库
mysql
source /TrinityCore/sql/create/create_mysql.sql
show databases;
#导入auth数据表
use auth
source /TrinityCore/sql/base/auth_database.sql
#导入characters数据表
use characters
source /TrinityCore/sql/base/characters_database.sql
```

# 打开端口并启动服务器
```
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 1119 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 1119 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8081 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8081 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8085 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8085 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8086 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8086 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart
iptables-save
iptables-apply
iptables --list

cd /home/wow/server1002
mkdir log
cd /home/wow/server1002/bin
nohup ./bnetserver -c /home/wow/server1002/etc/bnetserver.conf > /home/wow/server1002/log/bnetserver.log 2>&1 &
cd /home/wow/server1002/data
screen ../bin/worldserver -c /home/wow/server1002/etc/worldserver.conf
```

### 创建战网账号
```
#TC命令：
bnetaccount create test@test test
#启用GM账号
account set gmlevel 1#1 3 -1
```

### 登录游戏用户名/密码
```
test@test/test
```



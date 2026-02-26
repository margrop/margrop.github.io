---
title: 如何使用CentOS 7运行N2N—edge篇
tags:
  - n2n
  - network
  - centos
  - edge
published: true
hideInList: false
isTop: false
categories:
  - network
  - n2n
date: 2021-01-16 14:00:18
feature:
---
`边缘节点（node）`：将成为虚拟网络一部分的节点。

<!-- more -->

# 已编译好的文件
> 编译环境：
> CentOS Linux release 7.9.2009 (Core)
> Linux version 3.10.0-1160.11.1.el7.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-44) (GCC) ) #1 SMP Fri Dec 18 16:34:56 UTC 2020

```bash
yum install openssl
wget https://download.margrop.net/d/oneindex/network/n2n_2.8_stable/CentOS7/edge -O edge
```

# 手工启动edge
* 给予可执行权限
> 若直接下载的可执行文件，请自行copy到下面的路径

```bash
chmod +x /usr/local/sbin/edge
```

* 测试是否能正常启动
> 提示：下面的 `-a` `-c` `-k` `-l`参数，请根据需求，自行修改

```bash
edge -d h0 -a 10.0.0.1 -c margrop -k UFDMIlrK3ueQz5mS -l blog.margrop.net:2345 -r -v -f
```

* edge参数简单解释，详情解释直接在命令行输入edge

 参数名 | 英文                                                       | 中文 | 样例 
---- | ---|---- |---- 
-d | tun device | 虚拟网卡名称 | -d h0
-a | Set interface address. For DHCP use '-r -a dhcp:0.0.0.0' | 虚拟IP |  -a 10.0.0.1
-c | n2n community name the edge belongs to. | Community名称（即虚拟网用户名） | -c margrop
-k | Encryption key (ASCII) - also N2N_KEY=<encrypt key>. | Community密码（即虚拟网密码） |  -k UFDMIlrK3ueQz5mS
-l | Supernode IP:port | Supernode地址，域名:端口或IP:端口 |  -l blog.margrop.net:2345
-r | Enable packet forwarding through n2n community. | 启用通过n2n Community转发数据包。          |  -r
-v | Make more verbose. Repeat as required. | 启动verbose模式，打印更多的日志 |  -v
-f | do not fork and run as a daemon; rather run in foreground. | 不要Fork并作为守护进程运行，而是在前台运行 |  -n

# 自动启动edge

* 编辑systemctl的启动文件

```bash
vim /etc/systemd/system/edge.service
```

```bash
[Unit]
Description=N2N Edge Run On Port 2012 UDP
After=supernode.target

[Service]
Type=simple
ExecStart=/usr/local/sbin/edge -a 10.0.0.1 -c margrop -k UFDMIlrK3ueQz5mS -l blog.margrop.net:2345 -r -v -f
TimeoutStartSec=0

[Install]
WantedBy=supernode.target
```

* 启动服务

```bash
systemctl daemon-reload
systemctl stop edge
systemctl start edge
systemctl status edge
```

* 设置为自动启动
```bash
systemctl enable edge
```

# 下面为可选设置，若看不懂，忽略即可
* 启用CentOS的ip_forward
```bash
vim /etc/sysctl.conf
```

加入此行
```bash
net.ipv4.ip_forward = 1
```

加载sysctl
```bash
sysctl -p
```

* 配置CentOS的路由表`（重要：不能加入自己本地的网段路由）`
```bash
route del -net 192.168.1.0 netmask 255.255.255.0 gw 10.0.0.1
route add -net 192.168.1.0 netmask 255.255.255.0 gw 10.0.0.1
route del -net 192.168.103.0 netmask 255.255.255.0 gw 10.0.0.103
route add -net 192.168.103.0 netmask 255.255.255.0 gw 10.0.0.103
route del -net 192.168.113.0 netmask 255.255.255.0 gw 10.0.0.113
route add -net 192.168.113.0 netmask 255.255.255.0 gw 10.0.0.113 
```
* 打开Firewalld防火墙，启用NAT功能
```bash
firewall-cmd --set-default-zone=public
firewall-cmd --permanent --zone=public --change-interface=sh0
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --zone=public --list-all
firewall-cmd --reload
firewall-cmd --list-all
firewall-cmd --get-active-zones
```

# 参考文献
1.[n2n实现内网穿透](https://www.jianshu.com/p/5021b70c3ff9)
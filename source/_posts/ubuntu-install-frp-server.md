---
title: 'Ubuntu安装Frp服务端，非客户端'
date: 2021-01-23 13:43:20
tags: [ubuntu,frpc,frps,bash,github,nohup,server]
published: true
hideInList: false
feature: 
isTop: false
---
# 下载并解压Frp
* 最新Frp下载地址：<https://github.com/fatedier/frp/releases/>
```bash
cd ~
mkdir frp
cd frp
wget https://github.com/fatedier/frp/releases/download/v0.35.0/frp_0.35.0_linux_amd64.tar.gz
tar -xvzf frp_0.35.0_linux_amd64.tar.gz
cd frp_0.35.0_linux_amd64
```

<!-- more -->

# 配置Frp
* 删除默认配置文件
```bash
cd ~/frp/frp_0.35.0_linux_amd64/
rm frpc
rm frpc.ini
rm frpc_full.ini
ls -a
```

* 配置服务端配置文件
```bash
sudo su
rm frps.ini
cat>/etc/frps.ini<<EOF

[common]
#frp server 绑定的端口
bind_port = 1000
#设置 http 访问端口为 1001
vhost_http_port = 1001
#设置域名（保证此域名可用）
subdomain_host = frp.margrop.net

#配置 dashboard（可选）
dashboard_port = 3456
#dashboard 用户名密码，默认都为 admin
dashboard_user = admin
dashboard_pwd = admin

EOF
```

# 启动Frp服务端
```bash
cd ~/frp/frp_0.35.0_linux_amd64/
nohup ./frps -c /etc/frps.ini &
```

# 设置Frp服务端自启动
*  配置文件链接
```bash
ln -fs /lib/systemd/system/rc-local.service /etc/systemd/system/rc-local.service
cd /etc/systemd/system/
cat rc-local.service

echo >> rc-local.service
echo [Install] >> rc-local.service
echo WantedBy=multi-user.target >> rc-local.service
echo Alias=rc-local.service >> rc-local.service
```
 
* 赋可执行权限、编辑rc.local，添加需要开机启动的任务
```bash
echo '#!/bin/bash' >> /etc/rc.local
echo 'cd ~/frp/frp_0.35.0_linux_amd64/' >> /etc/rc.local
echo "nohup ./frps -c /etc/frps.ini &" >> /etc/rc.local
chmod 755 /etc/rc.local
cat /etc/rc.local
```

参考
<https://blog.csdn.net/u013144287/article/details/78589643>
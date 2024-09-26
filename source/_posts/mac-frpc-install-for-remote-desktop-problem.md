---
title: 'Mac安装Frp客户端，可使用远程桌面'
date: 2021-01-18 13:28:26
tags: [mac,frpc,frp,remote desktop,launchctl,brew,client]
published: true
hideInList: false
feature: 
isTop: false
---
可以使用brew进行安装
```bash
brew install frpc
vi /usr/local/etc/frp/frpc.ini
brew services start frpc
```

<!-- more -->

下面是之前手工解压的安装方法，有兴趣的可以看看
# 去[Frp官网](https://github.com/fatedier/frp/releases)下载Darwin包，并解压
* 略

# 复制可执行文件
```bash
sudo mv ~/Downloads/frp_0.34.3_darwin_amd64/frpc /usr/local/bin/
```


# 添加frpc配置文件
* 请自行修改`server_addr`、`server_port`、`remote_port`配置
```bash
sudo su
cat>/etc/frpc.ini<<EOF

[common]
server_addr = blog.margrop.net
server_port = 2345
 
[VNC-Mac-TEST-CLIENT]
type = tcp
local_port = 5900
remote_port = 3333

[SSH-Mac-TEST-CLIENT]
type = tcp
local_port = 22
remote_port = 3333

EOF
```

# 编辑自启动配置
```bash
sudo vi /Library/LaunchDaemons/frpc.plist
```
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC -//Apple Computer//DTD PLIST 1.0//EN
http://www.apple.com/DTDs/PropertyList-1.0.dtd >
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>frpc</string>
    <key>ProgramArguments</key>
    <array>
         <string>/usr/local/bin/frpc</string>
         <string>-c</string>
         <string>/etc/frpc.ini</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

* 自启动相关命令
```bash
launchctl load
launchctl unload
launchctl stop
launchctl start
```

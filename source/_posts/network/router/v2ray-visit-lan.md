---
title: '使用 v2ray 配置内网访问——基于公网IP'
date: 2023-03-25 15:44:58
tags: [v2ray,lan]
published: true
hideInList: false
feature: 
isTop: false
---
# 前提条件：
* 有公网IP

# 需求
* 需要进行安全的内网访问
* 需要加密流量
* 支持 TCP / UDP

<!-- more -->

*注：下面的UUID和端口号，请自行修改*

# v2ray配置文件[Server端]
```
{
    "inbounds": [
        {
            "port": 12345,
            "listen": "0.0.0.0",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "643773f3-568d-4655-bc48-a75afb2eccdd",
                        "level": 1,
                        "alterId": 16
                    }
                ]
            }
        },
        {
            "port": 12345,
            "listen": "0.0.0.0",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "643773f3-568d-4655-bc48-a75afb2eccdd",
                        "level": 1,
                        "alterId": 16
                    }
                ]
            },
            "streamSettings": {
                "network": "mkcp",
                "kcpSettings": {
                    "uplinkCapacity": 200,
                    "downlinkCapacity": 30,
                    "congestion": true,
                    "header": {
                        "type": "none"
                    }
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
```

# v2ray配置[Client端]
端口号：12345
UUID：643773f3-568d-4655-bc48-a75afb2eccdd
传输方式：tcp / mkcp
额外ID：0
UDP转发：打开
TLS：关闭
多路复用：关闭
TCP快速打开：关闭
算法：auto

# 增加防火墙配置端口
```
firewall-cmd --zone=public --add-port=12345/tcp --permanent
firewall-cmd --zone=public --add-port=12345/udp --permanent
firewall-cmd --reload
```

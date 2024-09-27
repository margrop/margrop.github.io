---
title: '搭梯子或机场：V2RAY配置WebSocket + TLS + Web + CDN'
date: 2021-01-26 13:44:36
cover: /images/banner/1009_20240927_021416.webp
coverWidth: 1280
coverHeight: 720
tags: [梯子,fuckgfw,gfw,websocket,tls,web,cdn,v2ray,caddy2]
published: true
hideInList: false
feature: 
isTop: false
---
`v2ray`现在最安全的配置就是`WebSocket + TLS + Web + CDN` 了，访问的是`443`端口，直接访问是一个网站，通过客户端连接后他是个梯子(飞机)。外观上看是一个刮胡刀，原来呢，它是一个吹风机。

<!-- more -->

# 1、检查系统的时间和时区是否正确，否则无法正常连接
* 本站博主曾因为服务器时间和时区的问题，导致无法正常连接`V2Ray`，折腾了一整天。
```bash
date
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date
```

# 2、自备海外VPS服务器  

* 自行购买一台海外VPS服务器，需要`KVM`的VPS，不要买成了`OpenVZ`，便宜没好货
* VPS服务器需要自带`独立IP`      
> 推荐：[VPEasy](https://www.vpeasy.com/)，老牌服务商，最低套餐1024M/1CPU/25G SSD/1T流量 ，KVM架构，每年28刀，首年使用`FirstYear`优惠码，可以75折。博主6年前开始购买，已经使用6年了。
![](/post-images/vpeasy-transactions-1.jpg)
* 海外VPS服务器一般需要海外`Paypal`账号，`Visa`或者`MasterCard`的信用卡进行支付美元。

# 3、自备CloudFlare账号和域名
* 自行注册一个顶级域名，并将域名解析到`CloudFlare

## 3.1、国内目前最便宜的域名
* `DNSPod`国内`.xyz`域名注册，最低注册6元2年
> 访问<https://cloud.tencent.com/act/pro/DNSPodDomainsCarnival>，领取2张5元代金券
> 然后注册10位数字以下的`.xyz`域名，新注册8元，续费8元
> 注册时，可以使用5元代金券，减后只需要3元
> 然后立即续费1年，又可以使用5元代金券，减后又只需要3元
> 记得国内注册域名，都需要`实名认证`

## 3.2、海外注册域名
> 推荐：<https://namesilo.com>，推荐`top域名`，每年4.89刀
> 下面为`namesile.com`的修改域名解析服务器的方法，仅供参考
![](/post-images/namesile-dns-1.jpg)
![](/post-images/namesile-dns-2.jpg)
* 自行注册一个`CloudFlare`账号，并添加自己的域名
> 入口：<https://www.cloudflare.com> 
![](/post-images/cloudflare-addsite-1.jpg)
![](/post-images/cloudflare-addsite-2.jpg)
![](/post-images/cloudflare-addsite-3.jpg)
![](/post-images/cloudflare-addsite-4.jpg)
* 在`CloudFlare`里面的域名管理`DNS设置`中，新增`二级域名`，`A记录`指向`VPS`的`IP地址`，`Proxy Status`为默认值`Proxied`
![](/post-images/cloudflare-dns-add-1.jpg)
* 二级域名增加后，需要取域名管理界面的`SSL/TLS设置`，把`SSL/TLS`的加密模式改为`Full（strict）`，如果已经是的，就不用改。
![](/post-images/cloudflare-ssl-mode-1.jpg)




# 4、安装Caddy2

提供web服务的还有`Nginx` 和`Apache`，为什么选用`Caddy2`？
因为他简单，可以自动申请`SSL`证书。
原文中的`Caddy`已经无法正常从官网安装，这里是安装`Caddy2`的方法

> 可选从官网下载，或者从本站下载

## 从官网下载`Caddy2`
* 需要包含`CloudFlare`插件
* 目前为最新版本`v2.3.0 h1:fnrqJLa3G5vfxcxmOH/+kJOcunPLhSBnjgIvjXV/QTA=`
* 进入[官网下载](https://caddyserver.com/download)
* 选择`Platform`（大部分都是选`Linux amd64`），勾选CloudFlare插件，再点击`Download`
![](/post-images/caddyserver-download-1.jpg)
* 把下载到本地的`Caddy2`文件上传到VPS下面的`~/tools/caddy`目录即可。

## 从本站下载`Caddy2`
* 已含`CloudFlare`插件
* 目前为旧版本`v2.2.1 h1:Q62GWHMtztnvyRU+KPOpw6fNfeCD3SkwH7SfT1Tgt2c=`
* 进入VPS下面的`~/tools/caddy`目录，运行`wget`命令即可
```bash
mkdir -p ~/tools/caddy
cd ~/tools/caddy
wget -O caddy2 https://download.margrop.net/d/oneindex/CENTOS/caddy2_2.2.1
```

* 查看`Caddy2`版本
```bash
chmod +x caddy2
caddy2 -version
```

# 5、安装v2ray
* `v2ray`一键安装命令
```bash
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
```

* `v2ray`正常安装时的安装日志
```bash
installed: /usr/local/bin/v2ray
installed: /usr/local/bin/v2ctl
installed: /usr/local/share/v2ray/geoip.dat
installed: /usr/local/share/v2ray/geosite.dat
installed: /usr/local/etc/v2ray/config.json
installed: /var/log/v2ray/
installed: /var/log/v2ray/access.log
installed: /var/log/v2ray/error.log
installed: /etc/systemd/system/v2ray.service
installed: /etc/systemd/system/v2ray@.service
removed: /tmp/tmp.iO3bDdOqa9
info: V2Ray v4.33.0 is installed.
You may need to execute a command to remove dependent software: yum remove curl unzip
Please execute the command: systemctl enable v2ray; systemctl start v2ray
```

# 6、配置并启动v2ray
* 编辑`v2ray`配置文件
```bash
vim /usr/local/etc/v2ray/config.json
```

* JSON文件里面的`UUID`相当于密码，请务必自行生成并妥善保管
> Mac/Unix/Linux系统：控制台输入`uuidgen`，即可生成`UUID`
> Windows系统：PowerShell控制台输入`[guid]::NewGuid()`，即可生成`UUID`
* JSON文件里面的`{RANDOM_PATH}`为WebSocket的访问URL，以目前的使用经验，最好使用随机字符串。

```json
{
  "inbound": {
    "port": 10000,
    "listen":"127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "E5B33B5A-A241-4246-B8D9-A260FBBAFCCF",
          "alterId": 64
        }
      ]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
      "path": "/{RANDOM_PATH}"
      }
    }
  },
  "outbound": {
    "protocol": "freedom",
    "settings": {}
  }
}
```

* 启动V2Ray
```bash
systemctl start v2ray
```

* 设置V2Ray开机自启动
```bash
systemctl enable v2ray
```

# 7、配置Caddyfile2
在 `/etc/caddy ` 目录创建 `Caddyfile2` 文件，没有目录就创建目录，编辑`Caddyfile2`文件
```bash
mkdir /etc/caddy
cd /etc/caddy
vim /etc/caddy/Caddyfile2
```

* 下面为`blog.margrop.net`域名为本站域名，请自行修改，建议使用刚才配置的二级域名。
* `{RANDOM_PATH}`，必须和上面配置一样的。
* dns cloudflare 这里的配置为CloudFlare的API_KEY，请自行修改，这是[插件文档](https://caddyserver.com/docs/modules/dns.providers.cloudflare)
```json
blog.margrop.net
{
    root * /usr/share/caddy
    file_server
    log {
        output file /var/log/caddy/vps.log
    }
    tls {
        dns cloudflare g9_uKv1RrXXXXXXHOPfXXXXXXYNZGXXXXXXJh3qp
    }
    @v2ray_websocket {
        path /{RANDOM_PATH}
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @v2ray_websocket localhost:10000
}
```

# 8、配置Caddy JSON
* `Caddy2`的主要配置文件是`Caddy JSON`，但这个配置文件太难写了。
* 所以我们这里把上一步编辑好的`Caddyfile2`文件转换成`Caddy JSON`文件
```bash
cd ~/tools/caddy
./caddy2 adapt --config /etc/caddy/Caddyfile2 > ~/tools/caddy/config.json
cat ~/tools/caddy/config.json
```

# 9、启动并上传Caddy JSON
* 启动`Caddy2`
```bash
cd ~/tools/caddy
./caddy2 start
```

* 上传`Caddy JSON`
```bash
curl localhost:2019/config/
curl localhost:2019/load -X POST -H "Content-Type: application/json" -d @config.json
curl localhost:2019/config/
```

# 10、v2ray客户端配置
* `v2ray`客户端建议和服务端的版本保持一致
* 这里客户端同时启用的`socks5`代理和`http`代理，均无验证，`socks5`代理使用`1080`端口，`http`代理使用`1081`端口， 且都支持局域网内连接，方便同一局域网下的其他设备搭乘顺风机。
```json
{
    "inbounds": [
        {
            "port": 1080,
            "listen": "0.0.0.0",
            "protocol": "socks",
            "domainOverride": [
                "tls",
                "http"
            ],
            "settings": {
                "auth": "noauth",
                "udp": false
            }
        },
        {
            "port": 1081,
            "listen": "0.0.0.0",
            "protocol": "http",
            "domainOverride": [
                "tls",
                "http"
            ],
            "settings": {
                "auth": "noauth",
                "udp": false
            }
        }
    ],
    "outbound": {
        "protocol": "vmess",
        "settings": {
            "vnext": [
                {
                    "address": "blog.margrop.net",
                    "port": 443,
                    "users": [
                        {
                            "id": "E5B33B5A-A241-4246-B8D9-A260FBBAFCCF",
                            "alterId": 64
                        }
                    ]
                }
            ]
        },
        "streamSettings": {
            "network": "ws",
            "security": "tls",
            "wsSettings": {
                "path": "/{RANDOM_PATH}"
            }
        }
    }
}
```
`UUID`，`域名`和`{RANDOM_PATH}`，必须和服务端配置一样的。

# 11、试运行

```
看看有没有报错，没有报错就访问下网站看是否正常，如果正常就证明caddy2配置无误。
```

> 以上全部操作在CentOS 7上亲自验证，可行。
> 目前这个文档还属于简版操作手册，后续再慢慢补充每一步详细的操作流程。

# 12、Caddy2配置自动启动
创建或编辑 caddy2.service 文件
使用以下命令编辑服务文件：

```
sudo nano /etc/systemd/system/caddy2.service
```
将服务文件内容更新为以下内容
```
[Unit]
Description=Start Caddy with Config on Boot
After=network.target

[Service]
User=root
WorkingDirectory=/root/tools/caddy
ExecStart=/root/tools/caddy/caddy2 run --config /root/tools/caddy/config.json
wqRestart=on-failure
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
```
重新加载 systemd 配置并启动服务
保存并关闭文件后，执行以下命令：

```
sudo systemctl daemon-reload
sudo systemctl restart caddy2.service
sudo systemctl enable caddy2.service
```
验证服务状态
检查服务是否正常运行：

```
sudo systemctl status caddy2.service
```

# 13、存档，Caddy1使用方法
```bash
#测试运行
caddy -agree -conf /etc/caddy/Caddyfile
#正式运行
nohup caddy -agree -conf /etc/caddy/Caddyfile > /root/caddy.log 2>&1 &
```

# 参考
[搭梯子：V2RAY配置WebSocket + TLS + Web](https://www.lingbaoboy.com/2019/03/v2raywebsocket-tls-web.html)
[WebSocket+TLS+Web](https://toutyrater.github.io/advanced/wss_and_web.html)
[Module dns.providers.cloudflare](https://caddyserver.com/docs/modules/dns.providers.cloudflare)
[Caddyfile Quick-start](https://caddyserver.com/docs/quick-starts/caddyfile)
[Install](https://caddyserver.com/docs/install)
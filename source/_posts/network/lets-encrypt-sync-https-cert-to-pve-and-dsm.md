---
title: 'Let''s Encrypt自动续期后自动同步Proxmox VE和DSM证书'
date: 2021-02-02 19:19:38
tags: [pve,Proxmox VE,dsm,https,ssl,sync,续期,证书,letsencrypt,cert,scp,群晖,key,pem,systemctl]
published: true
hideInList: false
feature: 
isTop: false
---

上次我们讲了[Let's Encrypt通过DNS TXT记录来验证域名有效性](https://blog.margrop.net/post/lets-encrypt-use-dns-txt-acme-challenge-domain-available/)，其中文章最后写了，如何使用`certbot renew`进行自动续期。那自动续期成功了，如何同步到`PVE`和`DSM`呢？

<!-- more -->

下面我们使用脚本来进行自动同步。

* 需要在`Proxmox VE`和`DSM`服务器配置`SSH`免密登录

# 自动同步Proxmox VE证书
* 同步到本机的`Proxmox VE`
```bash
cp /etc/letsencrypt/live/blog.margrop.net/fullchain.pem /etc/pve/local/pveproxy-ssl.pem
cp /etc/letsencrypt/live/blog.margrop.net/privkey.pem /etc/pve/local/pveproxy-ssl.key
systemctl restart pveproxy
```
* 同步到局域网的`Proxmox VE`
```bash
scp  /etc/letsencrypt/live/blog.margrop.net/fullchain.pem root@192.168.1.155:/etc/pve/local/pveproxy-ssl.pem
scp  /etc/letsencrypt/live/blog.margrop.net/privkey.pem root@192.168.1.155:/etc/pve/local/pveproxy-ssl.key
ssh root@192.168.1.155 "systemctl restart pveproxy"
```

# 自动同步DSM证书
* 同步到局域网的`DSM`
* 脚本里面的`gnEsPP`，每个群晖的路径都不一样，请根据实际情况自行替换。
```bash
scp  /etc/letsencrypt/live/blog.margrop.net/fullchain.pem root@192.168.1.55:/usr/syno/etc/certificate/_archive/gnEsPP/fullchain.pem
scp  /etc/letsencrypt/live/blog.margrop.net/privkey.pem   root@192.168.1.55:/usr/syno/etc/certificate/_archive/gnEsPP/privkey.pem
scp  /etc/letsencrypt/live/blog.margrop.net/chain.pem     root@192.168.1.55:/usr/syno/etc/certificate/_archive/gnEsPP/chain.pem
scp  /etc/letsencrypt/live/blog.margrop.net/cert.pem      root@192.168.1.55:/usr/syno/etc/certificate/_archive/gnEsPP/cert.pem
scp  /etc/letsencrypt/live/blog.margrop.net/fullchain.pem root@192.168.1.55:/usr/syno/etc/certificate/system/default/fullchain.pem
scp  /etc/letsencrypt/live/blog.margrop.net/privkey.pem   root@192.168.1.55:/usr/syno/etc/certificate/system/default/privkey.pem
scp  /etc/letsencrypt/live/blog.margrop.net/chain.pem     root@192.168.1.55:/usr/syno/etc/certificate/system/default/chain.pem
scp  /etc/letsencrypt/live/blog.margrop.net/cert.pem      root@192.168.1.55:/usr/syno/etc/certificate/system/default/cert.pem
```


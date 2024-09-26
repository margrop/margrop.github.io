---
title: 'Let''s Encrypt通过DNS TXT记录来验证域名有效性'
date: 2021-01-19 10:39:58
tags: [letsencrypt,dns,txt,renew,https,ssl,certbot,domain]
published: true
hideInList: false
feature: 
isTop: false
---
我们在使用`letsencrypt`获取免费的`HTTPS`证书的时候，`letsencrypt`需要对域名进行验证。默认情况下它的验证方式是这样的：
1. `certbot`程序在`web`目录的根目录下放置一个文件。
2. `letsencrypt`的服务器通过域名来访问这个文件，来验证你申请的域名是属于你的
但有时候我们想为内网的某台主机设置`HTTPS`，因为内网的主机无法被`letsencrypt`的服务器访问到，`certbot --nginx certonly`就会出现`Connection refused`的错误。

<!-- more -->

为了解决上述问题，我们可以更改验证方式，使用DNS记录来验证域名。

# 利用certbot获取证书
运行`sudo certbot --manual --preferred-challenges dns certonly`命令，输入域名并同意记录本机IP后开始获取证书，接着certbot就会弹出如下的提示：

```
-------------------------------------------------------------------------------
Please deploy a DNS TXT record under the name
_acme-challenge.example.com with the following value:

IMdfdsfsJDqBRyRaaEgPPQlEuvtxJQAgWZTIVbLuzDi8U

Once this is deployed,
-------------------------------------------------------------------------------
Press Enter to Continue
```
此时certbot程序就会暂停，等待我们去添加DNS记录。

* 添加DNS的TXT记录
看到上述的提示后，修改域名的DNS记录，添加一条TXT记录，主机名为`_acme-challenge`，而其中的内容就是`letsencrypt`生成的随机字符串`IMdfdsfsJDqBRyRaaEgPPQlEuvtxJQAgWZTIVbLuzDi8U`。

* 验证成功
添加好`DNS`记录后，我们可以通过`dig -t txt _acme-challenge.example.com`来查看域名的内容，域名生效以后，在`certbot`程序中下按下回车键，程序继续运行。`letsencrypt`对`DNS`记录验证成功，证书就申请成功了。

# 自动续期
现在`DNS`记录验证成功了，那如何自动续期呢？毕竟`letsencrypt`只有3个月，经常人工需续期太累了。

* 使用`certboot renew`命令进行续期。
```bash
certbot renew --force-renew --manual-auth-hook /root/renewdns.sh
```

* `--force-renew`参数代表强制进行SSL证书续期
* `--manual-auth-hook`参数代表自定义验证脚本，我这里脚本的内容就是更新域名`DNS`记录，就是上面说的主机名为`_acme-challenge`的TXT记录。
* 至于这里的自定义脚本怎么写，这个就需要看`DNS`服务商了，每家`DNS`服务商都不一样的。

> 这里是我自己的更新`TXT`记录脚本，仅适用于`freedns`，`{dns_cookie}`,`{domain_id}`,`{data_id}`请自行修改。
```bash
#/bin/bash
echo CERTBOT_VALIDATION = ${CERTBOT_VALIDATION}
curl -b "dns_cookie={dns_cookie}" -d "type=TXT" -d "subdomain=_acme-challenge" -d "domain_id={domain_id}" -d "data_id={data_id}" -d "address=%22${CERTBOT_VALIDATION}%22" https://freedns.afraid.org/subdomain/save.php?step=2
sleep 600
```

# 
<!-- more -->
参考文献
`certbot -h certonly`
`certbot -h renew`
<https://certbot.eff.org/docs/using.html>
<https://blog.csdn.net/u012291393/article/details/78768547>

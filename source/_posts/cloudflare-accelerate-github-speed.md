---
title: '利用cloudflare搭建gh-proxy加速github'
date: 2024-06-10 15:26:32
tags: [cloudflare,github,mirror,worker,fuckgfw]
published: true
hideInList: false
feature: 
isTop: false
---
前面几期有玩过青龙面板，但是如果要拉GitHub库就会遇到网络不行拉取失败的情况，平时github下文件速度也是奇慢无比，就用免费的cloudflare搭建gh-proxy加速GitHub。

**一、前提准备**

需要提前准备好cloudflare账号以及一个域名（可选），需要白嫖域名可以参考往期文章《[免费申请注册eu.org二级域名](http://mp.weixin.qq.com/s?__biz=MzIxMjE1NDQxNA==&mid=2247483945&idx=1&sn=abe651003c71d37c25b29cd6ea54a775&chksm=974b2368a03caa7e8ccdab8d0d104076540990a643731bd60bb9c3bbb04dc81c83dba4eedad9&scene=21#wechat_redirect)》

<!-- more -->

**二、部署gh-proxy**

登录cloudflare（https://dash.cloudflare.com/），转到Workers和Pages，概述，点击创建应用程序

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBAkvrC59kQVdibLvBwIiajKmMcrjTR8njl0EOQHLaDd4nd2sYXvpKdgVg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBCSVZtPnx3n3Ysrs9sxHn9ib8Kwtm8zOMhRfeW8LUCv4D6KVOP0Deoow/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

点击创建Worker，修改名称即可，同时还会得到一个**xxxx.xxxx.workers.dev**的域名（通过这个域名访问此服务），点击部署。

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBVIORW3d6LMQKdnV7G2h0akZbkbg2jcnKWicibvLiaHbHp0HFwmnwlic3Xg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

完成之后点击编辑代码，编辑js。

---

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejB6FsaE8rg8ycUM6pHh4VANSAKcjgz3XIWStErgcP8NRBXVaUPdQUzMw/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBJEL1cloKqWXZNWsibAtlibiceW1RibcCNjFHmRp653IwicYg1t08XJ5G7sg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

删除里面的内容，复制此js（https://cdn.jsdelivr.net/gh/hunshcn/gh-proxy@master/index.js）**所有内容到框内**，点击右上方保存并部署即可。

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBVu4ViaicIPJR6BfoCezqxTHSUwDAhTUe9nwC1raRY1hoBWibqx2AUeAOQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

这时候就可以访问刚刚的**xxxx.xxxx.workers.dev**来加速GitHub下载，但是这种域名太长了也不方便记忆，还可以添加自己的域名方便使用。

**三、绑定域名（可选）**

转到Workers和Pages-概述-刚刚部署的worker-触发器，点击添加自定义域名，输入自己的域名（要完整，比如**github.example.com**），点击添加自定义域名。

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBLZOVhWuHGGv13d56YurtRXDSH1rnicOnmQIETFjYYVibgibDXqu2WFhjg/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBLuhmUfgDibXf56rNhJsjjFdgjFciafR9k0Nq3jJbjv5tdHT314icKPBUQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBMzFCC6Iu1fdZSzy4QRkImH6sibYIcOibAwaMjaD6ZugbCRBU0Ciby252A/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

此时浏览器输入自己域名（**github.example.com**）即可访问。

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBN752wJ1picLn7JfCfLlribkbaA4RMjqHxCkCpEckZgyzegOiaIEWpPib6g/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

下载文件只需要链接前面加上自己的域名或者到web下载，青龙面板里订阅也是加上自己的域名就能加速拉取GitHub仓库。

![图片](https://mmbiz.qpic.cn/mmbiz_png/qOpcJV8aDreKGSbxUGfHHzf1FUyYqejBxMGt1QvD55zLEuOecHCSic7wsADYktib4xMULd5Vp7CaY81lZkes8BcQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

**注：workers每日总计免费10w次请求额度，普通人是几乎不可能用完，但为防止滥用仍建议添加路由和规则限制他人使用。**

**附上作者GitHub：https://github.com/hunshcn/gh-proxy**
---
title: 仅对Github的git clone进行代理
tags:
  - github
  - git
  - clone
  - proxy
  - socks
published: true
hideInList: false
isTop: false
categories:
  - network
  - Git
date: 2021-01-17 12:53:12
feature:
---
```bash
git config --global http.https://github.com.proxy socks5://127.0.0.1:1080
git config --global https.https://github.com.proxy socks5://127.0.0.1:1080
```

<!-- more -->

参考：
[一招 git clone 加速](https://juejin.im/post/6844903862961176583)
---
title: 更新 KoolProxyR 的规则地址，2021年2月12日更新
tags:
  - koolproxy
  - koolproxyr
  - rule
  - ad
published: true
hideInList: false
isTop: false
categories:
  - network
  - router
date: 2021-02-12 19:43:55
feature:
---
KoolProxyR 的规则地址已经好久没更新了，好多广告都没法过滤
只能自己改下更新地址了

<!-- more -->
# 编辑更新脚本
```bash
cd /koolshare/scripts
vim KoolProxyR_rule_update.sh
```

# 修改URL
`url_koolproxy`字段改为
```bash
url_koolproxy="http://bobohome.f3322.net:8880/files/KoolProxyRules/koolproxy.txt"
```
`url_yhosts`字段改为
```bash
url_yhosts="https://github.com/VeleSila/yhosts/blob/master/hosts"
```
`url_easylist`字段改为
```bash
url_easylist="https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt"
```

参考文章
<https://www.right.com.cn/forum/thread-3770004-1-1.html>
<https://github.com/VeleSila/yhosts>
<https://github.com/fang5566/uBlock/blob/master/README.md#ublock-origin>
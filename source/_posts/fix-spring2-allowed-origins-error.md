---
title: '修复 Spring 2.3.x 升级到更新版本出现的跨域问题'
date: 2023-03-12 20:20:01
tags: [Java,springfox,springboot,spring]
published: true
hideInList: false
feature: 
isTop: false
---
# 异常提示：
```
When allowCredentials is true, allowedOrigins cannot contain the special value "*" since that cannot be set on the "Access-Control-Allow-Origin" response header. To allow credentials to a set of origins, list them explicitly or consider using "allowedOriginPatterns" instead.
```

#解决办法：
跨域配置报错，将`.allowedOrigins`替换成`.allowedOriginPatterns`即可。

<!-- more -->

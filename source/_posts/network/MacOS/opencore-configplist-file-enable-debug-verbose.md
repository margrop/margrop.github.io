---
title: OpenCore 的 config.plist 文件，如何打印日志？
tags: []
published: true
hideInList: false
isTop: false
categories:
  - network
  - MacOS
date: 2021-12-14 20:37:35
feature:
---
# 准备工作
* PlistEdit Pro
* config.plist

# 开始
1. 使用PlistEdit Pro 打开 `config.plist`文件
2. 展开`NVRAM` -> `ADD` -> `7C436110-AB2A-4BBB-A880-FE41995C9F82`
3. 修改`boot-args`参数，在最末尾添加` -v`

<!-- more -->

# 更多参数参考
<https://blog.daliansky.net/OpenCore-BootLoader.html>
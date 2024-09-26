---
title: 'Vim打开文件中文乱码'
date: 2021-05-15 16:27:00
tags: [vim,Linux]
published: true
hideInList: false
feature: 
isTop: false
---
# 解决办法
* 编辑 ~/.vimrc 文件（没有则手动创建） 添加如下几行
```bash
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
set termencoding=utf-8
set encoding=utf-8
```

<!-- more -->

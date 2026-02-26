---
title: 'git删除远程分支报错: remote ref does not exist'
tags: []
published: true
hideInList: false
isTop: false
categories:
  - network
  - Git
date: 2021-08-27 10:48:48
feature:
---
# 问题描述
在视图删除某个远程分支的时候显示：`remote ref does not exist`

# 解决方案
解决方案是首先清除远程分支的本地缓存：`git fetch -p origin`
可以看到，我们要删除的远程分支其实已经删除了。

<!-- more -->

# 参考
<https://stackoverflow.com/questions/32147093/git-delete-remotes-remote-refs-do-not-exist>
<https://blog.csdn.net/Enjolras_fuu/article/details/95052803>
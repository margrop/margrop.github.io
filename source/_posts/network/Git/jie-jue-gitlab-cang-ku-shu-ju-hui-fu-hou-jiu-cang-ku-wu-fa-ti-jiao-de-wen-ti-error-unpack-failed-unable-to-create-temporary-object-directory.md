---
title: '解决 Gitlab 仓库数据恢复后，旧仓库无法提交的问题 error: unpack failed: unable to create temporary object directory'
date: 2021-08-24 10:05:20
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 问题描述
`Gitlab` 服务器刚进行完数据恢复

所有的旧仓库无法进行`git push`操作

错误提示`error: unpack failed: unable to create temporary object directory`

但是新增的仓库，可以正常进行`git push`

<!-- more -->

# 分析问题
搜索了一下网上的相关问题

主要问题是 `Gitlab` 的权限不够 

因为现在的 `Gitlab` 仓库文件是刚恢复的，文件的所有者是 root 账户，确实会有权限不够的问题

# 解决问题
进入`Gitlab`的`Docker`终端，修改所有的仓库，所属用户全改为`git`即可

```bash
cd /home/git/data/repositories
ll
chown -R git:git .
```

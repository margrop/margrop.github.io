---
title: Git常用命令
tags:
  - git
  - clone
  - svn
  - stash
  - commit
  - reflog
published: true
hideInList: false
isTop: false
categories:
  - network
  - Git
date: 2021-01-17 12:59:53
feature:
---
1. `git reflog` 显示git最近的一系列的操作记录
```
git reflog head@{0}
```

<!-- more -->

2. `git svn clone` 从svn库检出至本地git库
```
git svn clone -T trunk -b branch -t tags
```
3. `git svn dcommit` 从本地git库提交至svn
```
git svn dcommit --rmdir
```
4. `git stash` 将当前的改动保存至暂存区（压栈）
5. `git stash pop` 从暂存区取出最近一次保存的改动（弹栈）
6. `git gc --aggressive` 以最高压缩率，压缩git仓库
7. `git bundle create` 将git整个项目打包为一个bundle文件，方便移动或者长久保存
```
git bundle create GIT_BUNDLE_FILE --all
```
8. `git add` 增加提交文件
`git add *.*` 将所有新增文件增加至提交中
`git add -u` 移除所有已经删除的文件至提交中
9. `git commit` 提交历史
```
git commit -m "Commit Log"
```

---
title: PVE因boot空间不足而升级失败的解决办法
tags:
  - pve
  - boot
  - pvekclean
  - Proxmox VE
  - kernel
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-01-17 19:25:59
feature:
---
默认安装时，`proxmox`给`/boot`分配的空间才不到300M。而`proxmox`的迭代很快，`/boot`很容易就被占满，稍不注意就导致升级失败，唯一的做法就是手工删除旧的kernel。

<!-- more -->
# 删掉旧kernel
`proxmox`基于`debian`，每次使用`apt update && apt dist-upgrade`时，都会自动安装debian的`linux-image`，还有`pve-kernel`。这两货都会占用`/boot`的空间，所以腾空间就是删掉这两个旧`kernel`。
* 抄下在用kernel
```bash
uname -mrs
```
* 找出老旧kernel
```bash
dpkg --list | grep "linux-image"
dpkg --list | grep "pve-kernel"
```
* 删除之
```bash
apt purge linux-image-$old_version
```
NOTE: `proxmox`因为`/boot`空间不足而升级失败的话，`update-grub`也会失败，不过不用担心，每次使用`apt purge`旧内核时，都会重新`update-grub`。自然会将最新的`kernel`作为首选启动项，如果不放心，可以使用`grub-set-default $menuentry_id`和`grub-reboot $menuentry_id`来手工设置下一次启动的默认`kernel`
上述的步骤还是稍显麻烦，时不时都得惦记着`/boot`，好在还有两种懒人的方法：
1. https://github.com/jordanhillis/pvekclean
2. 在`proxmox`安装的时候，手工将/boot分区设为2G，至少可以清净一段时间。

参考文章
[proxmox因/boot空间不足而升级失败的解决办法](https://zhuanlan.zhihu.com/p/66171555)
[pvekclean](https://github.com/jordanhillis/pvekclean)
---
title: Linux启动时，如何编辑GRUB2的启动参数
tags:
  - Linux
  - boot
  - grub
published: true
hideInList: false
isTop: false
categories:
  - network
date: 2021-12-08 09:29:58
feature:
---

# To edit Grub2 during the boot process try the following:
# 为了在启动时，编辑GRUB2，可以尝试下面的步骤

1. Immediately after the BIOS splash screen during boot, press and hold the `SHIFT` button. This will display you `grub` containing a list of kernels and recovery options
在启动过程中出现 BIOS 启动画面后，立即按住`SHIFT`按键。
这将显示包含内核和恢复选项列表的`grub`。
![](/post-images/ZlSUO.png)

<!-- more -->

2. Press `e` to edit the first kernel displayed
按`e`编辑显示的第一个内核
![](/post-images/\/BnUQa.png)

3. Find the line ending with `quiet splash`. Add your boot option before these key words - i.e. so the line looks like [...] `nomodeset quiet splash`
找到以 `quiet splash` 结尾的行。 在这些关键字之前添加您的引导选项 - 即该行看起来像 [...] `nomodeset quiet splash`

4. Press `CTRL` + `X` to boot
按`CTRL`+`X`启动

# 参考文章
<https://askubuntu.com/questions/38780/how-do-i-set-nomodeset-after-ive-already-installed-ubuntu>
<https://www.dell.com/support/kbdoc/zh-cn/000123893/%E6%89%8B%E5%8A%A8-nomodeset-%E5%86%85%E6%A0%B8%E5%BC%95%E5%AF%BC-%E8%A1%8C%E9%80%89%E9%A1%B9-%E7%94%A8%E4%BA%8E-linux-%E5%BC%95%E5%AF%BC>
---
title: 'N5105 Promox VE 8.2版本，虚拟机频繁死机问题处理'
date: 2024-05-04 07:55:22
tags: [n5105,Proxmox VE,pve,intel,microcode]
published: true
hideInList: false
feature: 
isTop: false
---
# 一、问题背景
最近五一各大PT网站开发注册，于是乎注册了几家网站，然后为了做新手任务，疯狂下载上传，作为软路由的 N5105 、iKuai 在长时间高负载时，虚拟机会出现随机性的死机，CPU长期保持100%，只能杀掉再重启虚拟机，相当影响完成新手任务。死机了几次后终于受不了了，看网上各大同仁，发现同样问题不在少数。

下面是CSDN其他同仁的问题描述：

> 使用 N5105 作为 HomeLab 的服务器；之前安装的 ESXi，使用 Ubuntu 22 的时候经常会出现 Ubuntu CPU 占用达到100%，然后死机；但是其他的虚拟机都没有问题，因为对 Linux 并不熟，查看了 ESXi 和 Ubuntu 日志并没有异常；后面安装黑群晖一直失败，因此换到了 Proxmox VE

> 换到 PVE 后依然存在同样的问题，以为是服务的问题，于是给 Docker 容器添加了资源限制，无效后迁移到了 CentOS 部署，发现还是同样的问题；并且越来越频繁，从一天一次变成了几小时一次，几乎无法使用

<!-- more -->

> 猜测会不会是硬件问题，一番搜索发现在 N5105 上居然是个普遍的问题

>> 这个问题于 2022-08-04 在 Proxmox 的问题反馈中提交：[Bug 4188 - VMs freeze on Intel N5105 CPU](https://bugzilla.proxmox.com/show_bug.cgi?id=4188)，描述中"到运行Intel N5105 CPU的一些用户注意到在Proxmox上运行的虚拟机会冻结，并记录了各种错误。虚拟机会冻结，控制台无法输入，CPU利用率达到最大值，直到强制重启虚拟机"，现象和我遇到的是一样的，说明该现象是通病；

![img](https://img.hellowood.dev/picture/homelab-pve-vm-freeze-issue-bug-feedback.png)

>> 2022-9-13 在帖子 [Opt-in Linux 5.19 Kernel for Proxmox VE 7.x available](https://forum.proxmox.com/threads/opt-in-linux-5-19-kernel-for-proxmox-ve-7-x-available.115090/) 中，PVE员工宣布将 PVE 的内核升级到 5.19版本，在 Bug 反馈到讨论中有不少人确认有效

![img](https://img.hellowood.dev/picture/homelab-pve-vm-freeze-issue-519-kenel.png)

>> 这个问题在 2022-12-06 状态变更为 ‘FIX PACKAGED’；在 2022-12-14，PVE员工宣布支持将内核升级到 6.1

![img](https://img.hellowood.dev/picture/homelab-pve-vm-freeze-issue-61-kenel.png)

>> 在 Bug 反馈的最后几条评论中，反馈死机的问题在升级 5.19 或 6.1 的内核后确实减少了，但是依然可能出现
![img](https://img.hellowood.dev/picture/homelab-pve-vm-freeze-issue-bug-comments2.png)

<!-- more -->

# 二、解决方法——基于PVE8.2亲测

* 关闭企业订阅源
> 该订阅源是付费版本的订阅源，提供例如集群管理、备份和恢复等功能，未购买时无法使用，因此需要将其移除；为了保险将文件重命名为 backup
```bash
mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.backup
```
* 添加非订阅源
>“pve-no-subscription” 是 Proxmox VE 软件包源名称中的一个参数，代表这个软件包源提供的是免费版本的 Proxmox VE 软件包， “bookworm” 是 Debian GNU/Linux 操作系统的一个版本号，是该操作系统的第11个主要发行版
```bash
echo 'deb http://mirrors.ustc.edu.cn/proxmox/debian/pve bookworm pve-no-subscription' >> /etc/apt/sources.list.d/pve-no-subscription.list
```
* 添加 Debian non-free-firmware 源
> 添加 non-free-firmware 是为了更新 Microcode，默认的软件源不包含 non-free-firmware
```bash
tee /etc/apt/sources.list.d/debian-non-free.list > /dev/null <<EOF
deb http://mirrors.huaweicloud.com/debian unstable non-free-firmware
deb-src http://mirrors.huaweicloud.com/debian unstable non-free-firmware
EOF
```
* 查看当前的 `Microcode`，以下是当前的 `Microcode`，版本号`0x0000001d`
```bash
dmesg | grep microcode

[    0.378839] MMIO Stale Data: Vulnerable: Clear CPU buffers attempted, no microcode
[    0.378841] Register File Data Sampling: Vulnerable: No microcode
[    0.378842] SRBDS: Vulnerable: No microcode
[    1.268304] microcode: Current revision: 0x0000001d
```
* 安装 `Intel CPU microcode`
```bash
apt update -y
apt install intel-microcode -y
```
* 等待更新完成后重启即可
```bash
reboot
```
* 查看 `Microcode` 版本，可以看到更新到 0x24000026 版本
* 查询[debian更新日志](https://launchpad.net/debian/+source/intel-microcode/+changelog)显示，该版本为2023-09-26更新
```bash
dmesg | grep microcode

root@pve247:~# dmesg | grep microcode
[    0.372747] SRBDS: Vulnerable: No microcode
[    1.268720] microcode: Current revision: 0x24000026
[    1.268722] microcode: Updated early from: 0x0000001d
```
# 三、相关解释
* 安装源
> 在Debian操作系统中，软件包分为三个部分：main，contrib和non-free。其中，main 和 contrib 部分的软件都是自由软件，它们遵循自由软件定义（Free Software Definition），可以自由地使用、修改、复制和重新分发。

> 而 non-free 部分则包含了一些不符合自由软件定义的软件，例如某些专有硬件驱动程序、特定格式的音频和视频编码器等。这些软件可能有一些限制，例如不允许用户对其进行修改或重新分发。因此，这些软件在Debian社区中并不被认为是自由软件。

> `deb http://deb.debian.org/debian bullseye main contrib non-free` 这是Debian操作系统的主要软件源，其中包含了Debian操作系统的核心软件包和一些第三方软件包，其中contrib和non-free分别代表自由度不同的软件包。

> `deb http://security.debian.org/debian-security bullseye-security main` contrib non-free 这个源提供了Debian操作系统安全更新的软件包。这些软件包通常修复已知的漏洞和安全问题。

> `deb http://deb.debian.org/debian bullseye-updates main contrib non-free` 这个源提供了针对Debian操作系统稳定版本的非安全更新的软件包。这些软件包通常修复错误并提供新功能。

* 处理器微码(`[Microcode](https://wiki.debian.org/Microcode)`)。

> intel-microcode 作用是为英特尔处理器提供微码（microcode）更新。微码是一组指令，类似于处理器固件，可以在处理器上执行，以改变其行为或修复错误，内核能够在不需要通过BIOS更新的情况下更新处理器的固件。微码更新保存在易失性存储器中，因此BIOS/UEFI或内核会在每次启动时更新微码

> intel-microcode 的更新通常由操作系统或设备厂商提供，旨在提高处理器的性能、稳定性和安全性。

* Proxmox VE大版本与对应的Debian版本及其版本代号：

| Proxmox VE 版本 | Debian 基础版本 | Debian 版本代号 |
|----------------|-----------------|-----------------|
| Proxmox VE 8.x | Debian 12       | bookworm        |
| Proxmox VE 7.x | Debian 11       | bullseye        |
| Proxmox VE 6.x | Debian 10       | buster          |
| Proxmox VE 5.x | Debian 9        | stretch         |
| Proxmox VE 4.x | Debian 8        | jessie          |

# 四、参考文章
<https://blog.csdn.net/u013360850/article/details/129769334>
<https://chat.openai.com/share/71e270ee-a0b7-4b58-96b1-eb27cb21b044>
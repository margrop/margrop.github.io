---
title: Ubuntu / CentOS 磁盘根目录在线扩容 & 修改分区 inode 数量
tags:
  - ubuntu
  - lvm
  - resize
published: true
hideInList: false
isTop: false
categories:
  - network
  - Ubuntu
date: 2023-03-25 13:42:44
feature:
---
Ubuntu 作为服务器系统使用的时候，系统盘的空间可能并不是很充裕，apt apt 着，根目录就满了。诚然，增加磁盘 / 分区并挂载是一个方案，但并不能解决所有问题（例如 apt）。同时，一些跑在云平台上的服务器并没有很好的离线操作磁盘的手段，这时候在线扩容就显得极为必要了。

**数据无价！对磁盘进行任何操作前，请务必做好备份！**

# 0. 简要操作步骤
```shell
#系统分区扩容
parted -l
fdisk -l
cfdisk

#扩容块（sda3）
lsblk
pvresize /dev/sda3
lsblk

#扩容lv和vg（Ubuntu）
lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
df -h

#扩容lv和vg（CentOS）
lvextend -l +100%FREE /dev/mapper/centos-root
resize2fs /dev/mapper/centos-root
df -h
```

# 1. 磁盘根目录在线扩容
操作环境：Proxmox VE 虚拟化 / Ubuntu 22.04.5 LTS / GPT 分区表 / ext4 分区

<!-- more -->

## 1.1 增大物理磁盘容量
这部分没什么好说的，虚拟机就在设置里改，云平台就在对应的平台修改。修改好之后 Ubuntu 应该就可以直接识别到新的容量了。

## 1.2 将容量合并进分区
首先运行  `fdisk -l`  命令查看磁盘容量是否被识别：

![](/post-images/ubuntu_disk_resize_inode/step_1.png)

从上图可以看到，磁盘容量已被正确识别为 64GiB，但分区表记录的磁盘容量仍为扩容前的 40GiB（见红色提示，错误已被识别到），分区大小也是同样的 40G。

## 1.3 修复分区表
运行  `parted -l`  查看分区情况。
parted 会立即提示磁盘的空间并没有被全部使用，这里输入 Fix 后回车，修复一下 GPT 分区表。

![](/post-images/ubuntu_disk_resize_inode/step_2.png)

从上图中已经可以看到，分区表记录的磁盘容量已经正常。

## 1.3.1 检查并充值
运行`lsblk` 命令查看变化

运行`pvresize /dev/sda3`命令将`partition`增加的容量"充值"到PV中

## 1.4 扩容分区
现在就可以将空闲的磁盘容量合并到分区里了，这里利用界面和操作都更加友好的 `cfdisk` 来进行操作。
按上下键选中要扩容的分区，再按左右键选择 Resize 操作，回车。`cfdisk` 应该会自动填写此分区与未分配空间的总容量，也可以自己输入扩容后的大小，回车即可。

![](/post-images/ubuntu_disk_resize_inode/step_3.png)

下图中的 sda2 分区已经变为 64G，分区扩容完毕。但此时的所有操作仅在内存中完成，我们需要选择 Write 来将更改保存到分区表。写入后退出 `cfdisk`。

![](/post-images/ubuntu_disk_resize_inode/step_4.png)

再次执行 `fdisk -l` ，可见分区容量已变为 64G。

## 1.5 扩容文件系统
此时扩容并未结束，因为文件系统记录的分区容量仍为 40G，我们需要让文件系统知道分区已被扩容。

![](/post-images/ubuntu_disk_resize_inode/step_5.png)

这里需要用到 `resize2fs`，以我的磁盘 sda2 为例，执行以下命令：
```
resize2fs -p /dev/sda2
```
![](/post-images/ubuntu_disk_resize_inode/step_6.png)

等待操作完成即可。根据上图提示，我们已经完成了对文件系统的在线扩容。

## 1.6 Q & A
若执行 `resize2fs -p /dev/sda2` 命令时，出现下面的错误提示
```
resize2fs 1.42.9 (28-Dec-2013)
resize2fs: Bad magic number in super-block while trying to open /dev/centos/root
Couldn't find valid filesystem superblock.
```
检查 /dev/centos/root 文件系统，发现是xfs，如下;
```
# mount |grep root
```
提示如下：
```
/dev/mapper/centos-root on / type xfs (rw,relatime,attr2,inode64,noquota)
```
xfs的文件系统重新定义大小用如下命令：
```
# xfs_growfs /dev/mapper/centos-root 
```
提示如下：
```
meta-data=/dev/mapper/centos-root isize=256 agcount=4, agsize=3276800 blks
 = sectsz=512 attr=2, projid32bit=1
 = crc=0 finobt=0
data = bsize=4096 blocks=13107200, imaxpct=25
 = sunit=0 swidth=0 blks
naming =version 2 bsize=4096 ascii-ci=0 ftype=0
log =internal bsize=4096 blocks=6400, version=2
 = sectsz=512 sunit=0 blks, lazy-count=1
realtime =none extsz=4096 blocks=0, rtextents=0
data blocks changed from 13107200 to 39336960
```
重新进行df -h查看挂载点，发现大小已经更改。

# 2. 逻辑分区扩容
显示当前容量
```
vgdisplay
```
结果显示为
```
  --- Volume group ---
  VG Name               ubuntu-vg
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  2
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               1
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               <96.95 GiB
  PE Size               4.00 MiB
  Total PE              24818
  Alloc PE / Size       12409 / 48.47 GiB
  Free  PE / Size       12409 / 48.47 GiB
  VG UUID               0r0B09-AHil-bc9D-fXtF-o3Y3-MjZj-T10Sf9
```

## 2.2 选择全部扩容
扩展逻辑卷的逻辑边界
```
lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
```
## 2.3 使用`resizefs2`命令重新加载逻辑卷的大小才能生效
```
resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
```

# 3. 修改磁盘 inode
**对于 ext4 文件系统，inode 会在格式化时被写死，若要修改必须重新格式化，丢失所有数据，请务必注意。**
`xfs` 等文件系统提供 inode 的动态扩展功能。

## 3.1 查看磁盘 inode 情况
运行  `df -i` 查看各个分区的 inode 使用情况。

![](/post-images/ubuntu_disk_resize_inode/step_7.png)

从上图可以看到我的 sdc1 分区已经用尽了所有 4,194,304 个 inode，此时表现为`无法写入任何数据`，提示`磁盘已满`（即使仍有可用空间）。

## 3.2 重新格式化分区
在格式化分区的时候，可以利用 -N 参数指定 inode 数量。
以格式化 sdb1 为具有 16,777,216 个 inode 的 ext4 分区为例，执行以下命令：
```
mkfs.ext4 /dev/sdb1 -N 16777216
```
mkfs 会提示磁盘已存在格式化后的文件系统，确认后等待格式化完成即可。

![](/post-images/ubuntu_disk_resize_inode/step_8.png)

## 3.3 检查 inode 数量
运行以下命令：
```
dump2fs -h /dev/sdb1 | grep node
```
结果如下图，可以看到 `Inode count` 一项已经变为我们指定的值。

![](/post-images/ubuntu_disk_resize_inode/step_9.png)



# 来源
<https://www.npbeta.com/2020/12/ubuntu_disk_resize_inode/>
<https://blog.90.vc/archives/164>
<https://zhuanlan.zhihu.com/p/161533381?utm_id=0>
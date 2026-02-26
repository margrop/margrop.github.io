---
title: 在 Proxmox VE 里面，如何导入第三方的虚拟机镜像？
tags:
  - pve
  - kvm
  - qemu
  - vmdk
  - qcow2
  - import
  - 导入
  - 虚拟机
  - 镜像
  - image
  - Proxmox VE
  - img
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-02-01 15:12:47
feature:
---
下面的例子，`虚拟机ID`均以`100`为例，需自行修改。

# 文件格式转换
* 使用qemu-img 文件将其他格式的虚拟机硬盘文件转出`qcow2`格式
* 例如，下面是将`vmdk`格式转换为`qcow2`格式

<!-- more -->

```bash
qemu-img convert -f vmdk /mnt/usb/windows-server/windows-server.vmdk -O qcow2 /var/lib/vz/images/100/windows-server.qcow2
```

# 增加虚拟磁盘
* 先在Web界面增加一个`local`的虚拟磁盘，比如自动生成了`vm-100-disk-0.qcow2`

# qcow2文件类型
将该镜像复制到 `/var/lib/vz/images/100/` 这个目录下面

# 编辑虚拟机配置文件
```bash
vim /etc/pve/qemu-server/100.conf
```

找到`vm-100-disk-0.qcow2`，将这个文件改成需要的文件名即可。

# 删除空的虚拟磁盘
* 手工进入`/var/lib/vz/images/100/`目录，删除第一步新建的空虚拟磁盘文件`vm-100-disk-0.qcow2`
```bash
cd /var/lib/vz/images/100/
rm vm-100-disk-0.qcow2
```

参考文章
[QEMU-IMG](https://manpages.debian.org/testing/qemu-utils/qemu-img.1.en.html)
[Migration of servers to Proxmox VE](https://pve.proxmox.com/wiki/Migration_of_servers_to_Proxmox_VE#Move_the_image_to_the_Proxmox_VE_Server)
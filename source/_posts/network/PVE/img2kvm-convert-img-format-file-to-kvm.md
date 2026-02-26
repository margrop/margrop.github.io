---
title: img2KVM，将IMG格式转换为KVM格式，安装DSM群晖虚拟机
tags:
  - img2kvm
  - img
  - kvm
  - dsm
  - pve
  - Proxmox VE
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2021-01-20 08:32:25
feature:
---
# 安装img2kvm
```bash
cd /root
wget -c https://download.margrop.net/d/oneindex/network/PVE/img2kvm -O img2kvm
chmod +x img2kvm
```

<!-- more -->

# 使用img2kvm
* 所用的命令格式为：
```bash
img2kvm <img_name> <vm_id> <vmdisk_name> [storage]
```
其具体参数说明如下：
`img_name`：是IMG文件名称。一般为“xxx.img”或“xxx.img.gz”的格式。img2kvm可以直接识别并转换“img.gz”压缩格式的固件文件，对于“xxx.img.gz”来说，只需要输入“xxx.img”作为名称即可，不必再另外加“.gz”。
`vm_id`：是创建好的虚拟机的ID。一般为一组非零开头的数字，如100。
`vmdisk_name`：是虚拟机要使用的磁盘名称。建议采用vm-<vm_id>-disk-<disk_id>的命名方式，如vm-100-disk-1。
`storage`：是指导入使用的存储池的ID，默认为“local-lvm”，这是安装PVE时自动创建的。此项为可选项，若不指定则使用默认值。
接下来，只需要在面板上，分配硬盘即可。
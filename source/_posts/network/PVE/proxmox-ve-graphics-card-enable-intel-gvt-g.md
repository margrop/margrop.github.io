---
title: '【转】Proxmox VE开启显卡虚拟化intel GVT-g'
date: 2021-01-23 11:23:04
tags: [pve,Proxmox VE,intel,gvt-g,grub,modules,显卡虚拟化]
published: true
hideInList: false
feature: 
isTop: false
---
> 注意，intel gvt-g技术，PVE目前只支持第五代，第六代和第七代英特尔酷睿处理器以及E3 v4，E3 v5和E3 v6 Xeon处理器
> 8代和8代以上的CPU，博主亲测暂时不支持 -_-!
> 如果现在支持了，欢迎联系博主
> 参考：<https://pve.proxmox.com/wiki/PCI(e)_Passthrough>

<!-- more -->

终于搞到了一台实验机子。本次实验环境为：
```
PVE: 6.2
CPU: g5400
主板: 铭瑄h110
```

# 第一步：开启主板的虚拟化，这个自行在主板中开启。
# 第二步：开启PVE的直通功能
* 开启iommu和GVT-g支持

```bash
#开启iommu和gvt内核 
#编辑grub
vi /etc/default/grub
在里面找到：GRUB_CMDLINE_LINUX_DEFAULT="quiet"
然后修改为：
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on i915.enable_gvt=1"

#update grub
update-grub
```

* 加载直通内核模块
```bash
echo vfio >> /etc/modules
echo vfio_iommu_type1 >> /etc/modules
echo vfio_pci >> /etc/modules
echo vfio_virqfd >> /etc/modules
echo kvmgt >> /etc/modules
```
* 屏蔽驱动
```bash
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist snd_hda_codec_hdmi" >> /etc/modprobe.d/blacklist.conf 
echo "blacklist i915" >> /etc/modprobe.d/blacklist.conf 
```
* 将显卡加入直通
* 通过`lspci`命令查看核显序号，一般是00:02.0 。这里以00:02.0 为例
```bash
#查看直通设备
root@pve2:~# lspci -n -s 00:02.0
00:02.0 0380: 8086:3e90
#将8086:3e90 这个设备加入直通组
echo "options vfio-pci ids=8086:3e90" > /etc/modprobe.d/vfio.conf
```

# 第三步：重启主机
# 第四步：验证是否开启GVT
```bash
ls /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types/  #自觉将00:02换成自己的。
```
#出现下面4个选项或者类似的即成功。
```bash
i915-GVTg_V5_1	i915-GVTg_V5_2	i915-GVTg_V5_4	i915-GVTg_V5_8
```
# 第五步：创建虚拟机
![](/post-images/gvt-g1.jpg)

新建`OVMF EFI`虚拟机，把`cpu类型`设置成`HOST`。将主板设置成`q35`。安装好系统，开启远程桌面。关机，将虚拟机显卡设置成无。添加`PCIE`设备。
![](/post-images/gvt-g2.jpg)
# 总结

开启简单，但是性能稍微有些弱了一点，`GVT-G`技术， 并不像`s7150/nvidia k1`那样，将显卡独立成几个模块，反而是共享显卡的性能。
我开了2个虚拟机，其中一个进行`3D`测试的时候，另外一台显卡占用竟然满载。
![](/post-images/gvt-g3.jpg)
---
title: '黑苹果（Hackintosh）核显或非核显处理器，如何修改 OpenCore 配置文件'
date: 2021-09-13 16:48:17
cover: /images/banner/1010_20240927_021443.webp
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
> 注：以下仅针对类似配置机型，即9代`Intel`的CPU，其他机型请绕道

# 重要说明
1. `OpenCore`里面配置<font color="#dd0000" size="6">二进制均为倒序</font>，例如下面的`platform-id`，如果需要修改其他机型的，需要倒序后再填入`platform-id`
2. 这里是`黑果小兵`大神整理的`Coffee Lake帧缓冲区补丁及UHD630 Coffee Lake ig-platform-id数据整理`
> <https://blog.daliansky.net/Coffee-Lake-frame-buffer-patch-and-UHD630-Coffee-Lake-ig-platform-id-data-finishing.html>
4. 这里是`黑果小兵`大神整理的`黑苹果必备：Intel核显platform ID整理及smbios速查表`
> <https://blog.daliansky.net/Intel-core-display-platformID-finishing.html>

# 通用说明：如何修改三码
下载整包后，如果之前在 Clover 时就使用`iMac19,1`机型，可直接使用之前的三码，或使用 [Clover Configurator](https://mackie100projects.altervista.org/download-clover-configurator/) （其他工具亦可）选择`iMac19,1`机型生成新的三码 + ROM，用 ProperTree 打开`/EFI/OC/config.plist`文件，填入到 PlatformInfo > Generic 位置中（如下图）。
![](https://raw.githubusercontent.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI/master/Images/Explain/ProperTree_PlatformInfo.png)

<!-- more -->

# 有核显，有独显
1. 填入`iMac19,1`机型的三码 + ROM 信息到`/EFI/OC/config.plist`文件 `PlatformInfo > Generic` 处。
2. 将`/EFI/OC/config.plist`文件 Kernel > Add > 10 和 11 中 Enabled 的`Ture`手动修改为`False`（如下图）。
默认的是 9600K 专用的 HWP 变频文件，其他处理器不可启用！
![](https://raw.githubusercontent.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI/master/Images/Explain/ProperTree_Kernel_CPU.png)

保存后，先通过 USB 测试引导，无问题后将 EFI 文件夹放置到启动磁盘 EFI 分区，重启电脑。

# 无核显，有独显
1. 填入`iMacPro1,1`机型的三码 + ROM 信息到`/EFI/OC/config.plist`文件 PlatformInfo > Generic 处，并将机型修改为`iMacPro1,1`。
2. 将`/EFI/OC/config.plist`文件 Kernel > Add > 10 和 11 中 Enabled 的`Ture`手动修改为`False`。
因 `iMacPro1,1`机型不支持 HWP 变频，也可直接删除这两个条目和相关 kext 文件。
3. 删除`/EFI/OC/config.plist`文件 DeviceProperties > Add > PciRoot(0x0)/Pci(0x2,0x0) 下 `AAPL,ig-platform-id` 这一行参数（如下图）。
![](https://raw.githubusercontent.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI/master/Images/Explain/ProperTree_DeviceProperties.png)

4. 右键点击`/EFI/OC/Kexts/USBPower.kext`文件——显示包内容，进入`Contents`文件夹，打开`Info.plist`文件，将机型修改为`iMacPro1,1`（如下图）。
![](https://raw.githubusercontent.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI/master/Images/Explain/ProperTree_USBPower_Info.png)

保存后，先通过 USB 测试引导，无问题后将 EFI 文件夹放置到启动磁盘 EFI 分区，重启电脑。

# 有核显，无独显
1. 填入`Macmini8,1`机型的三码 + ROM 信息到`/EFI/OC/config.plist`文件 PlatformInfo > Generic 处，并将机型修改为`Macmini8,1`。
2. 使用非 `9600K` 处理器，将`/EFI/OC/config.plist`文件 Kernel > Add > 10 和 11 中 Enabled 的`Ture`手动修改为`False`。
`Macmini8,1 机型支持 HWP 变频，对于非 `9600K` 处理器可稍后自行定制 HWP 变频文件。
3. 修改`/EFI/OC/config.plist`文件 DeviceProperties > Add > PciRoot(0x0)/Pci(0x2,0x0) 下 `AAPL,ig-platform-id` 参数为`07009b3e`，并新增 `framebuffer-unifiedmem` 参数为`00000080`（如下图）。
![](https://raw.githubusercontent.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI/master/Images/Explain/ProperTree_DeviceProperties_I.png)
4. 右键点击`/EFI/OC/Kexts/USBPower.kext`文件——显示包内容，进入`Contents`文件夹，打开`Info.plist`文件，将机型修改为`Macmini8,1`。

保存后，先通过 USB 测试引导，无问题后将 EFI 文件夹放置到启动磁盘 EFI 分区，重启电脑。

# Q&A
1. **开机时苹果 logo 显示不正常怎么办？**
   有两个方法可以解决这个问题。
   方法一：在`/EFI/OC/config.plist`配置文件 UEFI > Output > Resolution 处填写正确的显示器分辨率；
   方法二：将 BIOS「STTINGS\启动\全荧幕商标」设置为 [允许]。
   两种方法选择其一即可，如果同时使用的话开机 logo 的显示依旧会不正常，原本更推荐方法二（会比方法一进入系统登陆界面略快一些），但反复测试后发现，如果在 BIOS 打开「Windows 10 WHQL支持」，使用方法二可能会导致**关机再开机时丢失苹果 logo**，请测试后选择~~适合~~自己喜欢的方法。
   **P.S.** 如果使用 2K 分辨率及以下无法开启 HiDPI 的显示器，需要将配置文件 NVRAM > Add > 4D1EDE05-XXXX > UIScale 设置为`01`。
2. **无法正常进入睡眠状态怎么办？**
   目前所知的情况是 ~~bugOS~~macOS 10.15.2 至 10.15.4（包括补充更新版本）都存在睡眠相关 bugs，如果使用了最新的 EFI 仍然无法正常进入睡眠，请尝试到「系统偏好设置——安全性与隐私——隐私——定位服务」关闭「Siri 与听写」，并尽量关闭「系统服务」中的定位权限。
   部分机器需要将`/EFI/OC/config.plist`文件 Config > Kernel > Quirks > PowerTimeoutKernelPanic 设置为 Ture/Yes 才可以正常睡眠，原因尚不明确（同型号主板、同版本 BIOS）。
3. **为什么推荐拥有核显的 CPU？**
   首先，macOS Catalina 原生支持 4K 双硬解的独显最低为 RX VEGA⁵⁶，而第七代及以后的酷睿处理器核显可以和低于 RX VEGA⁵⁶ 的独显协同工作，完成 4K 双硬解；
   其次，因为黑果没有 T2 芯片，所以没有核显的黑果无法使用随航（Sidecar）功能。
4. **引导过程触发原生快捷键怎么这么难？**
   我也被这个问题困扰了许久，在 OC 0.5.5 之前尝试过各种配置组合，均无法触发，但 OC 更新 0.5.5 后，通过设置 TakeoffDelay 参数可在引导过程中触发原生快捷键，建议在启动时按住组合键，或键盘灯亮起时不断重按组合键，可自行调整 TakeoffDelay 参数。
5. **NVMe 硬盘温度过高怎么办？**
   一般来说读写速度越快的硬盘温度往往越高，无需太过担心，但待机情况下超过 50℃ 或你认为硬盘的温度不正常，可尝试加载 [NVMeFix](https://github.com/acidanthera/NVMeFix/releases) 解决。
   将 NVMeFix.kext 放入`/EFI/OC/Kexts/`目录，打开`/EFI/OC/config.plist`，在 Kernel > Add 处添加 NVMeFix.kext（参考其他 kext 的添加方式）。
6. **可以观看 Apple TV+ / Netflix 等 DRM 媒体吗？**
   得益于 WhateverGreen 的功能，添加 shikigva=80 启动参数后，拥有独立显卡的机器都可以直接使用 tv 应用，并观看 Apple TV+，也支持 Safari 硬解观看 Netflix / Amazon Prime 等流媒体。
   macOS 10.15.4 之前版本，RX 4XX/5XX 大部分显卡不可使用 Safari 硬解 DRM（表现为冻屏），但这一问题在 10.15.4 中已经被修复，直接升级系统即可。
   *注意：因为缺少 Apple Firmware，导致 iGPU 无法硬解 DRM，所以没有独显的机器无法观看 DRM 媒体。*
7. **更新 OC 0.5.7 后睡眠唤醒不正常怎么办？**
   可参考这个 [Issue](https://github.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI/issues/35) 尝试解决。
8. **为什么没有开启 OC 0.5.9 中的启动项高优先级功能？**
   经测试，开启该功能后可能会造成无法设置 “启动磁盘” 的问题，默认未启用。如需启用该功能，请自行将配置文件 Misc > Security > BootProtect 设置为`Bootstrap`（关闭填写`None`）。
9. **如何使用 macOS Big Sur 11？**
   请确认你的 OpenCore 已更新到 0.6.1 以上版本，且所有 Kexts 也已更新到最新版，将配置文件 Kernel > Quirks > DisableLinkeditJettison 设置为 Ture/Yes 即可。
10. **待更新**

## 结语
完成以上步骤后，基本上已经有了一个完成度为 99% 的黑苹果设备，更多截图请查看 [截图预览](https://github.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI/tree/master/Images/Preview.md) 。
黑果和白果不一样，各种补丁和新系统的兼容性可能存在问题，一旦稳定后，追新速度不要太快，待各路大佬测试、完善后再升级也不迟。

## 鸣谢
[xjn](https://blog.xjn819.com/)
[andot](https://github.com/andot/MSI-B360M-MORTAR-IMACPRO-EFI/)
[daliansky](https://github.com/daliansky) ([黑果小兵](https://blog.daliansky.net/))
[tonymoses](http://bbs.pcbeta.com/viewthread-1835637-1-1.html)
[cattyhouse](https://github.com/cattyhouse/oc-guide/)
[osx86zh](https://t.me/osx86zh/) ([Telegram](https://telegram.org/) 讨论组)

## 链接
OpenCorePkg [官方版本](https://github.com/acidanthera/OpenCorePkg/releases) [自动编译](https://github.com/williambj1/OpenCore-Factory/releases) / AppleSupportPkg [官方版本](https://github.com/acidanthera/AppleSupportPkg/releases) [自动编译](https://github.com/athlonreg/AppleSupportPkg-Factory/releases) / [MacInfoPkg](https://github.com/acidanthera/MacInfoPkg/releases) / [Lilu](https://github.com/acidanthera/Lilu/releases) / [AppleALC](https://github.com/acidanthera/AppleALC/releases) / [WhateverGreen](https://github.com/acidanthera/WhateverGreen/releases) / [IntelMausi](https://github.com/acidanthera/IntelMausi/releases) / [VirtualSMC](https://github.com/acidanthera/VirtualSMC/releases) / [CPUFriend](https://github.com/acidanthera/CPUFriend/releases) / [OcBinaryData](https://github.com/acidanthera/OcBinaryData) / [MaciASL](https://github.com/acidanthera/MaciASL/releases) / [ProperTree](https://github.com/corpnewt/ProperTree) / [Hackintool](https://www.tonymacx86.com/threads/release-hackintool-v2-8-6.254559/) / [HWMonitorSMC2](https://github.com/CloverHackyColor/HWMonitorSMC2/releases)

## 参考文章
<https://github.com/GeQ1an/MSI-B360M-MORTAR-HACKINTOSH-OPENCORE-EFI>

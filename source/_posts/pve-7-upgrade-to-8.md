---
title: 'ProxmoxVE 7.4升级到8.0，详细步骤'
date: 2023-07-08 10:25:13
tags: [pve,Proxmox VE]
published: true
hideInList: false
feature: 
isTop: false
---
# 第一步：详细阅读官方文档
https://pve.proxmox.com/wiki/Upgrade_from_7_to_8

**注意：**
如果远程使用ssh连接的话，建议先使用`screen`命令，避免网络不稳定，操作中断导致的各种问题

# 第二步：升级到最新的 7.4 版本
```
apt update -y && apt dist-upgrade -y

sed -i_orig "s/data.status === 'Active'/true/g" /usr/share/pve-manager/js/pvemanagerlib.js
sed -i_orig "s/if (res === null || res === undefined || \!res || res/if(/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i_orig "s/.data.status.toLowerCase() !== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy

pveversion
```

最新的版本是 7.4.15


<!-- more -->


# 第三步：检查是否有兼容性问题
```
pve7to8
```

# 第四步：备份并替换Debian源
```
cp /etc/apt/sources.list /etc/apt/sources.list_bak
sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
```

# 第五步：备份并新增PVE8升级源
```
cp /etc/apt/sources.list.d/pve-install-repo.list /etc/apt/sources.list.d/pve-install-repo.list_bak
sed -i -e 's/bullseye/bookworm/g' /etc/apt/sources.list.d/pve-install-repo.list
```

# 第六步：CEPH需要，这里略

# 第七步：开始正式升级
```
apt update
apt dist-upgrade
```
升级中会出现一些交互界面，下面是官网的建议
```
/etc/issue -> Proxmox VE will auto-generate this file on boot, and it has only cosmetic effects on the login console.
Using the default "No" (keep your currently-installed version) is safe here.

/etc/lvm/lvm.conf -> Changes relevant for Proxmox VE will be updated, and a newer config version might be useful.
If you did not make extra changes yourself and are unsure it's suggested to choose "Yes" (install the package maintainer's version) here.

/etc/ssh/sshd_config -> If you have not changed this file manually, the only differences should be a replacement of ChallengeResponseAuthentication no with KbdInteractiveAuthentication no and some irrelevant changes in comments (lines starting with #).
If this is the case, both options are safe, though we would recommend installing the package maintainer's version in order to move away from the deprecated ChallengeResponseAuthentication option. If there are other changes, we suggest to inspect them closely and decide accordingly.

/etc/default/grub -> Here you may want to take special care, as this is normally only asked for if you changed it manually, e.g., for adding some kernel command line option.
It's recommended to check the difference for any relevant change, note that changes in comments (lines starting with #) are not relevant.
If unsure, we suggested to selected "No" (keep your currently-installed version)
```

# 第八步：去掉未订阅提示
```
sed -i_orig "s/data.status === 'Active'/true/g" /usr/share/pve-manager/js/pvemanagerlib.js
sed -i_orig "s/if (res === null || res === undefined || \!res || res/if(/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i_orig "s/.data.status.toLowerCase() !== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
```

# Q&A
Q: 提示【Upgrade wants to remove package 'proxmox-ve' 】
A: 在升级前尝试执行【apt remove linux-image-amd64】

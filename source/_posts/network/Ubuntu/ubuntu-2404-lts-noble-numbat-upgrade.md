---
title: Ubuntu 24.04 LTS —— "Noble Numbat" 升级指南
tags:
  - ubuntu
published: true
hideInList: false
isTop: false
categories:
  - network
  - Ubuntu
date: 2024-04-30 19:55:19
feature:
---
感谢ChatGPT从官网翻译，[原文入口](https://help.ubuntu.com/community/NobleUpgrades)

重要提示：**[Ubuntu 22.04 LTS目前无法直接升级到 Ubuntu 24.04 LTS，请等到2024年8月再进行升级操作](https://help.ubuntu.com/community/NobleUpgrades)**

# Ubuntu 24.04 LTS —— "Noble Numbat" 升级指南
Ubuntu 24.04 LTS 是2024年4月发布的Ubuntu操作系统的版本。该版本的开发代号为“Noble Numbat”。

<!-- more -->

## 开始之前
你可以直接从Ubuntu 22.04 LTS（“Jammy Jellyfish”）或Ubuntu 23.10（“Mantic Minotaur”）升级到Ubuntu 24.04 LTS（“Noble Numbat”）。
Ubuntu 24.04 LTS发布后，升级功能并不会立即可用。从Ubuntu 23.10升级将在发布后不久启用，届时已知的升级问题将得到解决。从Ubuntu 22.04 LTS的升级在Ubuntu 24.04.1 LTS发布前将不可用，预计发布时间为2024年8月。
确保在升级前，你的当前Ubuntu版本已应用所有更新。
建议在升级前阅读Ubuntu 24.04 LTS的发布说明，其中记录了此版本已知问题的注意事项和解决方法。

如果你使用的是Ubuntu 22.04 LTS或23.10之外的版本，请参阅UpgradeNotes了解如何升级。

## 从22.04 LTS或23.10升级到24.04 LTS
### 升级Ubuntu桌面到24.04 LTS
你可以通过以下过程通过网络轻松升级：

1. 运行update-manager应用程序。
2. 在更新管理器中，点击设置按钮...，输入密码启动软件来源应用程序。
3. 在软件来源应用程序中选择“更新”子菜单。
4. 确认“通知我新版本的Ubuntu”选项设置为“对任何新版本”，如有不同请更改。
5. 关闭软件来源应用程序并返回更新管理器。
6. 在更新管理器中，点击检查按钮以查找新更新。
7. 如果有更新需要安装，使用安装更新按钮进行安装。
8. 运行update-manager。
9. 如果你想提前升级，在升级官方支持之前，可以在运行update-manager时传递-d选项。请自行承担风险。建议在此之前检查Ubuntu 24.04 LTS的发布说明。

   一个消息将出现，通知你新版本的可用性。
   点击升级。
10. 按照屏幕上的指示操作。

### Ubuntu服务器
如果还没有安装，安装ubuntu-release-upgrader-core：

```bash
sudo apt-get install ubuntu-release-upgrader-core
```

确保/etc/update-manager/release-upgrades中的Prompt行设置为'normal'，如果你想要非LTS升级，或设置为'lts'，如果你只想要LTS升级。
启动升级工具：

```bash
do-release-upgrade
```

如果你想提前升级，在升级官方支持之前，可以在运行do-release-upgrade时传递-d选项。请自行承担风险。建议在此之前检查Ubuntu 24.04 LTS的发布说明。

按照屏幕上的指示操作。

### Edubuntu
Edubuntu遵循与Ubuntu桌面相同的指示。

### Lubuntu
请参考[这里](https://manual.lubuntu.me/stable/D/upgrading.html)了解我们的升级指示。你可能会注意到没有新的细节，但如果找不到升级或其他问题，这可能会有帮助。

### Ubuntu Budgie
请参考[这里](https://ubuntubudgie.org/2024/04/ubuntu-budgie-24-04-release-notes/)了解我们的升级指示。

### Ubuntu Studio
请参考[这里](https://ubuntustudio.org/ubuntu-studio-24-04-lts-release-notes/#upgrading)了解升级指示。

### Ubuntu Kylin
请参考[这里](https://ubuntukylin.com/news/ubuntukylin2404-en.html)了解升级指示。

###
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTgwODU2OTkwXX0=
-->
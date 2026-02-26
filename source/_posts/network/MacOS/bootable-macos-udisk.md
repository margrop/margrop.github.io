---
title: '正版苹果系统U盘制作，MacOS，Macintosh，Hackintosh '
cover: /images/banner/1013_20240930_111226.webp
coverWidth: 1280
coverHeight: 720
tags:
  - macos
  - udisk
published: true
hideInList: false
isTop: false
categories:
  - network
  - MacOS
date: 2024-09-30 11:19:53
feature:
---
制作MacOS引导U盘的步骤如下：

### 准备工作：

1. **准备一个至少有16GB空间的U盘**：数据会被清除，请备份U盘中的重要文件。
2. **下载macOS安装程序**：你需要从Mac App Store或Apple官网上下载你想要的macOS版本（如macOS Ventura、Monterey等）。

### 步骤一：下载macOS安装程序

1. 打开Mac App Store，搜索你想要的macOS版本。
2. 点击“获取”或“下载”，系统会将安装程序下载到你的“应用程序”文件夹中。

### 步骤二：格式化U盘

1. 插入U盘。
2. 打开“磁盘工具”（可以通过Spotlight搜索“磁盘工具”来找到）。
3. 选择U盘名称（在左侧栏中），然后点击顶部的“抹掉”按钮。
4. 在弹出的窗口中，设置以下选项：

    * **名称**：你可以自定义名称，如“macOSInstaller”。
    * **格式**：选择“Mac OS扩展（日志式）”。
    * **方案**：选择“GUID分区图”。
5. 点击“抹掉”来格式化U盘。

### 步骤三：创建引导U盘

1. 打开“终端”应用（可以通过Spotlight搜索“终端”来找到）。
2. 输入以下命令，然后按回车。请确保修改命令中的`MyVolume`为U盘的名称：
    对于macOS Sonoma：

    ```bash
    sudo /Applications/Install\ macOS\ Sonoma.app/Contents/Resources/createinstallmedia --volume /Volumes/MyVolume
    ```

    对于macOS Ventura：

    ```bash
    sudo /Applications/Install\ macOS\ Ventura.app/Contents/Resources/createinstallmedia --volume /Volumes/MyVolume
    ```

    对于macOS Monterey：

    ```bash
    sudo /Applications/Install\ macOS\ Monterey.app/Contents/Resources/createinstallmedia --volume /Volumes/MyVolume
    ```

    对于macOS Big Sur：

    ```bash
    sudo /Applications/Install\ macOS\ Big\ Sur.app/Contents/Resources/createinstallmedia --volume /Volumes/MyVolume
    ```

    以上命令中的`Install macOS Ventura.app`或其他版本的安装程序名称，需要与下载的安装程序名称保持一致。
3. 按下回车后，系统会提示你输入管理员密码（注意输入时不会显示任何字符），然后按回车。
4. 终端会显示制作进度，等待完成即可。U盘会自动被重命名为安装程序的名称。

### 步骤四：使用引导U盘进行安装

1. 完成引导U盘的制作后，插入该U盘。
2. 重启Mac并在开机时按住`Option`（`⌥`）键，直到看到启动管理器。
3. 选择U盘启动，并按照屏幕上的指示进行macOS的安装。

这样，你就成功制作了一个macOS引导U盘，并可以用它来进行macOS的安装或升级。
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTczMjcxNjQwNV19
-->
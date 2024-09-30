---
title: 'MacOS 自定义登录和注销脚本'
date: 2021-11-04 10:44:50
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 登录和注销脚本（Login and Logout Scripts）
> `重要提示`：避免使用登录和注销脚本的原因有很多：
> `Important`: There are numerous reasons to avoid using login and logout scripts:
> * 登录和注销脚本是一种不推荐使用的技术。在大多数情况下，您应该改用launchd作业，如创建启动守护程序和代理中所述。
> * Login and logout scripts are a deprecated technology. In most cases, you should use launchd jobs instead, as described inCreating Launch Daemons and Agents.
> * 登录和注销脚本以 root 身份运行，这存在安全风险。
> * Login and logout scripts are run as root, which presents a security risk.
> * 一次只能安装每个脚本中的一个。它们适用于系统管理员；应用程序开发人员不应在已发布的软件中使用它们。
> * Only one of each script can be installed at a time. They are intended for system administrators; application developers should not use them in released software.

<!-- more -->

在登录时运行应用程序的一种方法是使用自定义 shell 脚本启动它们。创建脚本文件时，请记住以下几点：
One way to run applications at login time is to launch them using a custom shell script. When creating your script file, keep the following in mind:

* 脚本文件的权限应包括相应用户的执行权限。
* The permissions for your script file should include execute privileges for the appropriate users.
* 在您的脚本中，该变量$1返回登录用户的短名称。
* In your script, the variable $1 returns the short name of the user who is logging in.
* 其他登录操作会等到您的钩子完成执行。因此，您的脚本需要快速运行。
* Other login actions wait until your hook finishes executing. Therefore, your script needs to run quickly.

使用该`defaults`工具安装您的登录脚本。创建脚本文件并将其放在所有用户都可以访问的目录中。在终端中，使用以下命令安装脚本（其中`/path/to/script`是脚本文件的完整路径）：
Use the `defaults` tool to install your login script. Create the script file and put it in a directory that is accessible to all users. In Terminal, use the following command to install the script (where `/path/to/script` is the full path to your script file):
```
sudo defaults write com.apple.loginwindow LoginHook /path/to/script
```

要删除此挂钩，请删除该属性：
To remove this hook, delete the property:
```
sudo defaults delete com.apple.loginwindow LoginHook
```

使用相同的过程添加或删除注销挂钩，但键入`LogoutHook`而不是`LoginHook`。
Use the same procedure to add or remove a logout hook, but type `LogoutHook` instead of `LoginHook`.


> 注意： 如果不存在plist文件com.apple.loginwindow，则此方法将不起作用。在用户更改登录窗口设置（例如打开快速用户切换）之前，全新安装中不存在此文件（/var/root/Library/Preferences/com.apple.loginwindow.plist）。

> Note: If no plist file exists for com.apple.loginwindow, this method will not work. This file (/var/root/Library/Preferences/com.apple.loginwindow.plist) does not exist on a fresh installation until the user changes a login window setting (such as turning on fast user switching).

> 如果必须以编程方式安装启动脚本，则应考虑提供包含默认配置选项的此文件的副本。然后，如果该文件不存在，请在运行defaults之前将该默认配置文件复制到位。同样，强烈建议应用程序开发人员不要使用登录或注销脚本，因为只能安装一个这样的脚本。

> If you must install startup scripts programmatically, you should consider providing a copy of this file containing the default configuration options. Then, if the file does not exist, copy that default configuration file into place before running defaults. Again, application developers are strongly discouraged from using login or logout scripts, because only one such script may be installed.

# 参考文章
<https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CustomLogin.html>
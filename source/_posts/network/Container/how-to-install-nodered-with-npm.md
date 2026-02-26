---
title: 如何通过 NPM 安装 Node-RED
tags:
  - node
  - npm
  - nodejs
  - node-red
  - linux
  - centos
  - os
  - API
  - low-code
  - browser
  - 浏览器
  - 智能家居
  - 模块
  - 流程
  - flow
  - 安装
  - 启动
  - 升级
published: true
hideInList: false
isTop: false
categories:
  - network
  - Container
date: 2021-02-01 09:57:07
feature:
---
# `Node-RED`是什么
`Node-RED`是一种低代码/无代码编程工具，用于以新颖有趣的方式将`硬件设备`，`API`和`在线服务`连接在一起。特别适用于`智能家居`。

`Node-RED`提供了一个基于浏览器的流编辑器，可轻松使用面板中的各种节点将流连接在一起。然后，单击即可将流部署到运行时。

<!-- more -->

> 可以使用富文本编辑器在编辑器中创建`JavaScript`函数。
> 内置库允许您保存有用的功能，模板或流程以供重复使用。

## 建立在Node.js之上
> 基于`Node.js`构建，轻量级的运行环境，充分利用了事件驱动的非阻塞模型。这使得它非常适合在低成本的硬件（如`Raspberry Pi`）上的网络边缘以及云服务器运行。

> Node的软件包存储库中有超过225,000个模块，可以轻松扩展面板节点的范围以添加新功能。

## 社交共享
> 在`Node-RED`中创建的流使用`JSON`存储，可以轻松导入和导出以与他人共享。

> 在线流程库使您可以与世界分享最佳流程。

# 安装Node和NPM环境
* 之前有写过[`CentOS 7 安装最新版本Node和NPM`](https://blog.margrop.net/post/centos-7-install-node-and-npm-latest/)，CentOS 7可以参考
* 其他Linux建议参考[`在 Linux 上，通过二进制文件安装 Node.js`](https://github.com/nodejs/help/wiki/Installation)
* 其他OS建议参考[`在支持的平台上，使用源代码构建 Node.js`](https://github.com/nodejs/node/blob/master/BUILDING.md#building-nodejs-on-supported-platforms)

# 使用NPM安装
要安装`Node-RED`，您可以使用`node.js`附带的`npm`命令：
```bash
sudo npm install -g --unsafe-perm node-red
```
该命令会将`Node-RED`及其依赖项安装为全局模块。
如果命令输出的结尾类似于以下内容，则可以确认它已成功：
```bash
+ node-red@1.1.0
added 332 packages from 341 contributors in 18.494s
found 0 vulnerabilities
```

# 运行Node-Red
安装为全局模块后，您可以使用node-red命令在终端中启动Node-RED。您可以使用Ctrl-C或关闭终端窗口来停止Node-RED。

```bash
$ node-red

Welcome to Node-RED
===================

30 Jun 23:43:39 - [info] Node-RED version: v1.1.0
30 Jun 23:43:39 - [info] Node.js  version: v10.21.0
30 Jun 23:43:39 - [info] Darwin 18.7.0 x64 LE
30 Jun 23:43:39 - [info] Loading palette nodes
30 Jun 23:43:44 - [warn] rpi-gpio : Raspberry Pi specific node set inactive
30 Jun 23:43:44 - [info] Settings file  : /Users/nol/.node-red/settings.js
30 Jun 23:43:44 - [info] HTTP Static    : /Users/nol/node-red/web
30 Jun 23:43:44 - [info] Context store  : 'default' [module=localfilesystem]
30 Jun 23:43:44 - [info] User directory : /Users/nol/.node-red
30 Jun 23:43:44 - [warn] Projects disabled : set editorTheme.projects.enabled=true to enable
30 Jun 23:43:44 - [info] Creating new flows file : flows_noltop.json
30 Jun 23:43:44 - [info] Starting flows
30 Jun 23:43:44 - [info] Started flows
30 Jun 23:43:44 - [info] Server now running at http://127.0.0.1:1880/red/
```
然后，您可以通过将浏览器指向`http://localhost:1880`来访问`Node-RED`编辑器。

日志输出为您提供各种信息：
* `Node-RED`和`Node.js`的版本
* 尝试加载调色板节点时遇到任何错误
* 设置文件和用户目录的位置
* 它正在使用的流文件的名称。
`Node-RED`使用`flows_<hostname>.json`作为默认流文件。您可以通过提供流文件名作为`node-red`命令的参数来更改此设置。

# 使用命令行
可以使用命令启动Node-RED node-red。该命令可以使用各种参数：
```bash

node-red [-v] [-?] [--settings settings.js] [--userDir DIR]
         [--port PORT] [--title TITLE] [--safe] [flows.json|projectName]
         [-D X=Y|@file]
```
Option | Description
---|---
-p, --port | 设置运行时侦听的TCP端口。默认：1880
--safe	| 在不启动流程的情况下启动Node-RED。<br>这使您可以在编辑器中打开流并进行更改，而无需运行流。<br>当您部署更改时，流程就开始了。
-s, --settings FILE	 | 设置要使用的设置文件。默认值：`<userDir>/settings.js`
--title TITLE	 | 设置进程窗口标题
-u, --userDir DIR	 | 设置要使用的用户目录。默认：`~/.node-red`
-v	 | 启用详细输出
-?, --help	 | 显示命令行用法帮助并退出
flows.json|projectName	 | 如果未启用“项目”功能，则将设置要使用的流文件。如果启用了“项目”功能，这将标识应该启动哪个项目。

`Node-RED`使用`flows_<hostname>.json`作为默认流文件。如果运行的计算机可能会更改其主机名，则应确保提供一个静态文件名；作为命令行参数或使用设置文件中的flowsFile选项。

# 如何升级Node-RED
如果已将Node-RED作为全局npm软件包安装，则可以使用以下命令升级到最新版本：
```bash
sudo npm install -g --unsafe-perm node-red
```

# 参考文章
[Node-Red](https://nodered.org/)
[Node-JS](https://nodejs.org/zh-cn/download/)
[Running Node-RED locally](https://nodered.org/docs/getting-started/local#installing-with-npm)
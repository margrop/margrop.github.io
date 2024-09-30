
---
title: 'Hello，Hexo；Goodbye Gridea'
date: 2024-09-30 13:48:52
cover: /images/banner/1014_20240930_111226.webp
coverWidth: 1280
coverHeight: 720
tags: [macos,udisk]
published: true
hideInList: false
feature: 
isTop: false
---
经过几天的忙碌，终于将之前 `Gridea` 的全部文章内容与评论迁移到 `Hexo`，且保留了原有文章的URL不变。

`Gridea` 作为一个多年缺乏维护的项目，且缺乏定制化功能。

之前作为`Pages`的入门还行，但随着要求的提高，迁移成了必然选择。

作为

# Linux环境准备

## 安装`git`,`nodejs`和`npm`

```bash
#安装命令
apt install git nodejs npm -y

#检查安装结果
node -v
npm -v
```

## `npm`添加国内镜像

```bash
#添加华为云镜像地址
npm config set registry https://mirrors.huaweicloud.com/repository/npm/
```

## 使用`npm`安装 `hexo`

```bash
#安装 hexo
npm install -g hexo-cli
```

# 使用Hexo创建项目

## 创建项目目录并初始化项目

```bash
#创建目录并进入
mkdir -p ~/SITE/blog2
cd ~/SITE/blog2

#使用hexo初始化
hexo init 
hexo generate
hexo server

```

## 在项目目录下，使用 npm 安装相关插件

```bash
#安装Hexo主题相关插件
npm install hexo-theme-nexmoe hexo-renderer-inferno
npm install hexo-generator-feed
npm install hexo-generator-json-content
npm install hexo-generator-sitemap
npm install hexo-word-counter

#安装Github Pages部署相关插件
npm install hexo-generator-cname
npm install hexo-deployer-git
```

## 编辑项目配置

```bash
nano _config.yaml
nano _config.nexmoe.yml
```

## 使用hexo部署到github pages

```bash
#生成项目并部署
hexo g && hexo d
```
<!--stackedit_data:
eyJoaXN0b3J5IjpbNjM5NTUyMzMsLTYyMDM4MTEzNSw4NzczMD
gzNjBdfQ==
-->
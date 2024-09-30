---
title: 'OpenWRT / LEDE 设置跨网段访问方法'
date: 2021-12-04 11:17:47
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 1. 静态IPv4路由，增加路由表
* 访问`网络`->`静态路由`页面
需要填入`目标网段`,`IPv4子网掩码`,`IPv4网关`,

# 2. 防火墙，增加防火墙允许规则
* 访问`网络`->`防火墙`->`通讯规则`页面
需要填入`名称`,`匹配规则`,`动作`

<!-- more -->

## 名称
随便填入名字即可，例如`ALLOW-LAN`

## 匹配规则
转发`IPv4`，来自`lan`，到`lan`，IP `{目标网段}`

## 动作
当然是选择`Accept`
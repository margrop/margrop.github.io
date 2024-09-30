---
title: 'HomeAssistant：常用的 HACS，Github 第三方支持库 Repo'
date: 2021-03-15 08:56:00
tags: [homeassistant,github,repo]
published: true
hideInList: false
feature: 
isTop: false
---
# HACS
* HACS官方网站
> <https://github.com/hacs/integration>
> <https://hacs.xyz/>
* HACS安装文档
> <https://hacs.xyz/docs/installation/installation>

<!-- more -->

# 亲测米家系列
米家互联网空调，`zhimi.aircondition.ma3`
> <https://github.com/margrop/zhimi>
> 样例配置文件如下
```yaml
climate:
  - platform: xiaomi_miio_airconditioningcompanionmcn02
    name: 主卧空调
    host: 192.168.1.xxx
    token: 00000000996745e6373da0000000000
    target_sensor: sensor.none
    scan_interval: 60
  - platform: xiaomi_miio_airconditioningcompanionmcn02
    name: 次卧空调
    host: 192.168.1.xxx
    token: 00000000eb4b89209de37fd00000000
    target_sensor: sensor.none
    scan_interval: 60
```

小米空调伴侣2，`lumi.acpartner.mcn02`
> <https://github.com/EugeneLiu/xiaomi_airconditioningcompanionMCN02>
> 样例配置文件如下
```yaml
climate:
  - platform: zhiair
    name: 客厅空调
    host: 192.168.1.xxx
    token: 000000060cbdb81c632a6ea00000000
  - platform: zhiair
    name: 儿童房空调
    host: 192.168.1.xxx
    token: 0000000008a4efa9b0f3fb000000000
```

小爱触屏音箱，钉钉群的消息提醒，`xiaomi.wifispeaker.lx04`
> <https://github.com/Yonsm/ZhiMsg>
> <https://github.com/Yonsm/ZhiMi>
> <https://github.com/Yonsm/ZhiBot>
> 样例配置文件如下
```yaml
zhimsg:
  - platform: ding
    name: 钉钉信使
    token: !secret dingbot_token
    secret: !secret dingbot_secret
  - platform: miai
    name: 小爱触屏音箱
    did: 2671000000
    model: lx04

zhibot:
  - platform: genie
  - platform: miai
    token: !secret zhibot_token
  - platform: ding
    token: !secret zhibot_token
  - platform: ding
    name: 小爱触屏音响
    token: !secret zhibot_token
```

米家万能遥控器，`chuangmi.remote.v2`
> <https://github.com/custom-components/remote_homeassistant>
> 样例配置文件如下
```yaml
remote:
  - platform: xiaomi_miio
    host: 192.168.1.xxx
    token: 0000000649a5afc10f6fc60b0000000
    model: chuangmi.remote.v2
    name: 万能遥控 SH
    slot: 1
    timeout: 30
    hidden: false
```

米家智能插座基础版（WIFI），`chuangmi.plug.m1`，使用官方 `xiaomi_miio`即可
> <https://www.home-assistant.io/integrations/xiaomi_miio/>
> 样例配置文件如下
```yaml
switch: 
  - platform: xiaomi_miio
    name: N4插座SH主卧
    host: 192.168.1.xxx
    token: 00000000c002be49862b1d1e00000000  
    model: chuangmi.plug.m1
  - platform: xiaomi_miio
    name: N3插座SH主卧
    host: 192.168.1.xxx
    token: 0000000016e418341ece619100000000  
    model: chuangmi.plug.m1
```

# 亲测天猫精灵和小度音箱
> HAVCS全称为Home Assistant Voice Control Skill，诣在提供Home Assistant对接音箱平台的能力，通过在Home Assistant上运行本插件，可对接音箱厂家的技能开放平台（自建技能或用线上技能），响应音箱指令控制相关设备。
> <https://github.com/cnk700i/havcs>
* HAVCS 作者提供的：HAVCS食用说明
> <https://ljr.im/articles/plugins-havcs-edible-instructions/>
> 样例配置文件如下
```yaml
havcs:
  platform:
   - aligenie
   - dueros
  http:
    clients:
      aligenievisiter: Br9opxYY000000
    ha_url: https://blog.margrop.net
  device_config: ui
```

# 解决问题：HAVCS菜单套娃（HAVCS菜单无限嵌套显示）
![](https://img-blog.csdnimg.cn/img_convert/d764e11c237f13991268c6d5555c185b.png)
1. 进入`Supervisor`页面，打开加载项`File editor`，打开目录`custom_components/havcs/`
2. 将`index.html` 中的 `/havcs/` 替换为 `/havcshtml/`
3. 将`login.html` 中的 `/havcs/` 替换为 `/havcshtml/`
4. 找到`http.py`中的 `class HavcsDeviceView`类，查找下面代码段，将下面代码中`havcs`改为`havcshtml`
```py
hass.http.register_static_path('/havcs', local, False)
```
4. 还是`http.py`这个文件，查找下面代码段，将下面代码中`havcs`改为`havcshtml`
```py
config = {"url": '/havcs/index.html'}`
```
4. 检查无误后，重启 HA 

# 亲测 Apple 系列
iCloud设备
<https://github.com/gcobb321/icloud3>

# 参考文章
1. <https://ask.csdn.net/questions/4358468>
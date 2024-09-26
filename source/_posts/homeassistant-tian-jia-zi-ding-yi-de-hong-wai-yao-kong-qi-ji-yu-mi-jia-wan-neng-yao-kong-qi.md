---
title: 'HomeAssistant 添加自定义的红外遥控器，并支持天猫精灵和小度小度'
date: 2021-05-12 16:09:09
tags: [homeassistant,havcs,remote]
published: true
hideInList: false
feature: 
isTop: false
---
# 准备工作
* 已联网的`米家万能遥控器`，且已添加到`HomeAssistant`
* `米家万能遥控器`的`IP 地址`和`token`

> `IP 地址`如何获取？
> 在手机端打开`米家 APP`，选择已绑定小米账号的设备
> 点击进入，然后点右上角的`...`->`更多设置`->`网络信息`，即可查看设备的`IP 地址`

> `token`如何获取？
> 参考1：[使用开源工具导出小米Token](https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor)
> 参考2：[Retrieving the Access Token](https://www.home-assistant.io/integrations/xiaomi_miio/#retrieving-the-access-token)

<!-- more -->

# 学习自定义指令
1. 打开`HomeAssistant`->`开发者工具`->`服务`，在`服务`里面输入`xiaomi_miio.remote_learn_command`，然后`实体`里面找到对应的，比如我的『entity_id』是`remote.mo_neng_yao_kong_sh`
2. 点击按钮`调用服务`，然后在30秒内，拿遥控器对准米家万能遥控器，按需要学习的按键
3. 如果操作无误，系统会收到一条通知，通知内容就是按键红外指令的`base64`编码。

# 配置自定义指令
1. 打开`HomeAssistant`->`Supervisor`->`File editor`->`打开 Web UI`->`/config/configuration.yaml`
2. 在已有的`remote`段落下面，增加`commands`。
完整的示例配置如下
```yml
remote:
  - platform: xiaomi_miio
    host: 192.168.1.86
    token: 8ec29e26xxxxxxxxxfcxxxxd3c9ef9
    model: chuangmi.remote.v2
    name: 万能遥控 SH
    slot: 1
    timeout: 30
    hidden: false
    commands:
      bladeless_fan_on_off:
        command:
          - raw:mMynEwlk0mEwlkxmU1AIKZABlMQDDmwCNANeAQUzAIOaAI2AQk3As8Bp5xMwGrAj8AQwhimc5AasGLwffAaIEfwa/BrUFlg1/Br8GtACPBr8Gvwa/AjwBpBXoCG8GLwofCY8GsgFSEo8UPxyvE68H3wmKCGsNdga4C88GJ4A
      bladeless_fan_shake_head:
        command:
          - raw:mMynEwlkznMwlgBETSaAGHMwEaAa8AjwCPA+cDEpmByQCJziZgLIAiYKCAEMBZwNfgs+AR4H3g1+Ch4NfhQ2Cz4BDzUBHw1/Br8UPwa/Bi8Ajwa/Br8ZTwa/Fe8FnwCPEW8NfwUPBryAAA==
      bladeless_fan_speed:
        command:
          - raw:mMymswlk0mUwlkxmU4AIKYABlMQDDmwCNANTMwDDmgBFAfQBrAEfgNLOJnNwLKA18BrAaymc5BH8GtQofAIUFkgEcBr8LzwhvBH8AgwofAI8Ol5xMwJyCzgDXwa/BQ8CPgGvBr8GtQUPGv8UOwR/A18a/BQ/GU8ZSwGngAA=
      bladeless_fan_timer:
        command:
          - raw:mMymswlk0mUwlgBETSYAGHNwEaAamYgNMBHACMgEeARIHyTeazMFHwbPAa8Ej5ZNAQkmgDXg2eDZ4NngNeA1gNngx+A1kxmU4BsMBdACSmc5AIYE0wbPDZ8L7wCCmwBHgNYGzYNkBfeDZ4JHgtIGzoNngjsGzIKPi16AiUAA
      bladeless_fan_wind_type:
        command:
          - raw:mMymswlk0mUwlgBETSYgGHNgEaAa8AjwLMAa8AhZxMAR0ANMFDwPmAagAhgR/AIKaAEGAIk4mEsmc5ARoAjJvOQGiAjgCzpmA14DWAEeBH4DSBH2DWwXkAWeDX4MXg1+BH4BFhr+AIQNfAIsAQoE5Aj+BZ4EfgEMM4U3nIDRARwBZIDRAfZAAA==
```
上面的示例配置文件，我加入了5条自定义红外命令。

# 配置命令脚本（将命令实体化）
1. 打开`HomeAssistant`->`Supervisor`->`File editor`->`打开 Web UI`->`/config/scripts.yaml`
2. 增加配置文件，示例如下
```yml
bladeless_fan_on_off:
  alias: 开关
  sequence:
    - service: remote.send_command
      entity_id: 'remote.mo_neng_yao_kong_sh'
      data:
        command: 'bladeless_fan_on_off'
bladeless_fan_shake_head:
  alias: 摇头
  sequence:
    - service: remote.send_command
      entity_id: 'remote.mo_neng_yao_kong_sh'
      data:
        command: 'bladeless_fan_shake_head'
bladeless_fan_speed:
  alias: 风速
  sequence:
    - service: remote.send_command
      entity_id: 'remote.mo_neng_yao_kong_sh'
      data:
        command: 'bladeless_fan_speed'
bladeless_fan_wind_type:
  alias: 风类
  sequence:
    - service: remote.send_command
      entity_id: 'remote.mo_neng_yao_kong_sh'
      data:
        command: 'bladeless_fan_wind_type'
```
  
# HAVCS 设备添加
> 命令实体化以后，设备添加就非常简单了
1. 打开`HomeAssistant`->`HAVCS 设备`->`+`
2. 按各项内容填写即可，填完完成后点击`添加`
3. 所有的`HAVCS`设备添加完成后，点击`刷新`按钮即可

# 参考文章
* [Xiaomi IR Remote](https://www.home-assistant.io/integrations/xiaomi_miio/#xiaomi-ir-remote)
* [\[技术探讨\]新版HA如何加入小米万能遥控器 ](https://bbs.hassbian.com/thread-7413-1-1.html)
* [使用Home Assistant控制小米米家万能遥控器输出遥控信号](https://www.feeus.com/%E4%BD%BF%E7%94%A8home-assistant%E6%8E%A7%E5%88%B6%E7%B1%B3%E5%AE%B6%E4%B8%87%E8%83%BD%E9%81%A5%E6%8E%A7%E5%99%A8%E8%BE%93%E5%87%BA%E9%81%A5%E6%8E%A7%E4%BF%A1%E5%8F%B7/)
* [将小米米家万能遥控器添加到Home Assistant](http://www.feeus.com/%e5%b0%86%e7%b1%b3%e5%ae%b6%e4%b8%87%e8%83%bd%e9%81%a5%e6%8e%a7%e5%99%a8%e6%b7%bb%e5%8a%a0%e5%88%b0home-assistant/)

---
title: 'HomeAssistant配置：长时间忘记关闭防盗门时，自动提醒'
date: 2021-03-09 18:18:37
tags: [HA,小米,网关,Aqara,门窗传感器,智能音箱,TTS]
published: true
hideInList: false
feature: 
isTop: false
---
需要的设备：
`小米门窗传感器`，`小米Aqara网关`，`小米触屏音箱`

> 当门打开持续1分钟，和持续2分钟时，音箱会自动进行声音提醒关门

```yaml
description: ''
trigger:
  - type: opened
    platform: device
    device_id: 000000f29088665d7b820e7d4000000
    entity_id: binary_sensor.door_window_sensor_158d0002000000
    domain: binary_sensor
    for:
      hours: 0
      minutes: 1
      seconds: 0
      milliseconds: 0
  - type: opened
    platform: device
    device_id: 000000f29088665d7b820e7d4000000
    entity_id: binary_sensor.door_window_sensor_158d0002000000
    domain: binary_sensor
    for:
      hours: 0
      minutes: 2
      seconds: 0
      milliseconds: 0
condition: []
action:
  - service: zhimsg.xiao_ai_hong_ping_yin_xiang
    data:
      message: 主人，你还在吗，大门忘记关啦，以后记得关门哦
mode: single
```
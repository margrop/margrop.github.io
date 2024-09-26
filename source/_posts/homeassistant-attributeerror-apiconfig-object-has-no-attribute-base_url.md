---
title: '解决 HAVCS 在最新版本的 HomeAssistant 无法正常启动的问题，AttributeError: ''ApiConfig'' object has no attribute ''base_url'''
date: 2021-05-12 18:12:02
tags: [homeassistant,havcs]
published: true
hideInList: false
feature: 
isTop: false
---
# 不要频繁升级 HA【2021年5月15日更新】
`强烈不建议升级到 core-2021.3.1 以及之后的版本，包括 core-2021.5.3`
`从 core-2021.3.1 以后的版本有一些莫名的 bug，目前博主稳定使用的版本还是 core-2021.2.3`

# 问题描述
博主最近把 `HomeAssistant` 升级到最新版本后，`HAVCS` 就无法正常启动了

> `HomeAssistant`正常运行`HAVCS`的版本：core-2021.2.3
> `HomeAssistant`无法运行`HAVCS`的版本：core-2021.5.3


查看 `HomeAssistant` 的日志后发现，出现了一个错误
```
AttributeError: 'ApiConfig' object has no attribute 'base_url'
```

<!-- more -->

完整的错误信息如下：
```
Logger: homeassistant.config_entries
Source: custom_components/havcs/__init__.py:250
Integration: Home Assistant Voice Control Skill (documentation)
First occurred: 18:05:49 (1 occurrences)
Last logged: 18:05:49

Error setting up entry 主配置[configuration.yml] for havcs
Traceback (most recent call last):
  File "/usr/src/homeassistant/homeassistant/config_entries.py", line 269, in async_setup
    result = await component.async_setup_entry(hass, self)  # type: ignore
  File "/config/custom_components/havcs/__init__.py", line 250, in async_setup_entry
    http_manager = hass.data[DOMAIN][DATA_HAVCS_HTTP_MANAGER] = HavcsHttpManager(hass, conf.get(CONF_HTTP, {}).get(CONF_HA_URL, hass.config.api.base_url), DEVICE_CONFIG_SCHEMA)
AttributeError: 'ApiConfig' object has no attribute 'base_url'
```

# 查询问题
查阅相关资料和文档后发现，`HomeAssistant`已经把`config.api.base_url`作为了一个废弃的 API，需要使用新的`helpers.network.get_url`来替换该 URL

# 解决问题 
使用`File Editor`打开文件`/config/custom_components/havcs/__init__.py`，将所有的`config.api.base_url`替换为`helpers.network.get_url`，检查无误后，重启`HomeAssistant`即可

# 参考文章
<https://github.com/elupus/hass_nibe/issues/72>
<https://developers.home-assistant.io/blog/2020/05/08/instance-url-helper/>

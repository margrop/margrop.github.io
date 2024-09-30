---
title: 'AppDaemon （HADashboard）安装教程'
date: 2021-05-29 14:22:56
tags: [AppDaemon, HomeAssistant,HADashboard]
published: true
hideInList: false
feature: 
isTop: false
---

# 安装准备
* HomeAssistant 访问地址，以及永久 Token
* Linux 运行环境
* Python3 运行环境（下面是基于 CentOS 7 的）
```bash
yum install python3
pip install -U pip3 setuptools
```

<!-- more -->

# 安装 AppDaemon
```bash
pip3 install appdaemon
```

# 添加配置文件
> 需根据配置文件夹所在路径，自行修改`文件路径`
> 使用 Vim 编辑`AppDaemon`配置文件
```bash
vim /home/appdaemon/appdaemon.yaml
```
> `AppDaemon`配置文件内容如下
> 需根据配置文件夹所在路径，自行修改`经度`,`纬度`,`HA 路径`,`HA Token`
```yaml
appdaemon:
  time_zone: Asia/Shanghai
  latitude: 31.0
  longitude: 121.0
  elevation: 0
  plugins:
    HASS:
      type: hass
      ha_url: http://192.168.1.7:8123
      token: eyJ0eXAiOiJKV1QiLCJ
hadashboard:
http:
  url: http://0.0.0.0:5050
admin:
api:
```

# 手工启动 AppDeamon
> 需根据配置文件夹所在路径，自行修改命令
```bash
appdaemon -c /home/appdaemon/
```
# 自动启动 AppDeamon
* 使用 Vim 编辑`systemctl`配置文件
```bash
sudo vim /etc/systemd/system/appdaemon@appdaemon.service
```

* `systemctl`配置文件内容如下
> 需根据配置文件夹所在路径，自行修改`文件路径`
```
[Unit]
Description=AppDaemon
[Service]
Type=simple
ExecStart=/usr/local/bin/appdaemon -c /home/appdaemon/
[Install]
WantedBy=multi-user.target
```

* 相关命令
```bash
#重载配置文件
systemctl daemon-reload
#启动
systemctl start appdaemon@appdaemon.service
#自动启动
systemctl enable appdaemon@appdaemon.service
#重启动
systemctl restart appdaemon@appdaemon.service
```


# 参考文章
<https://appdaemon.readthedocs.io/en/latest/INSTALL.html#pip3>
<https://appdaemon.readthedocs.io/en/latest/DASHBOARD_CREATION.html#widget-reference>
<http://apod.top/index.php/post/114.html>
<https://bbs.hassbian.com/thread-388-1-1.html>
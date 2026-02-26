---
title: ProxmoxVE硬盘local-lvm监控、网线速率监控（Uptime Kuma）
cover: /images/banner/1016_20240930_111523.webp
coverWidth: 1280
coverHeight: 720
tags:
  - hexo
  - git
  - nodejs
  - npm
published: true
hideInList: false
isTop: false
categories:
  - network
  - PVE
date: 2024-09-30 17:45:22
feature:
---

## 背景一

最近无论是公司系统，还是家庭服务器，均爆出多起因为硬盘满，导致服务不可用的状况

且并不是全部不可用，而是部份功能不可用，或者不稳定，开始排查问题的时候也并没考虑硬盘满。

于是防范于未然，一不做二不休，给 Uptime Kuma 添加硬盘使用率监控，避免出现同样问题

> 该需求过于小众，于是自定义并集成到已有监控系统，方便统一监控页面



## 背景二

最近也出现多起软路由/NAS出口变成百兆速率，导致内网文件传输只有10M/s的问题

同样也给 Uptime Kuma 添加千兆速率监控，避免出现同样问题

> 该需求过于小众，于是自定义并集成到已有监控系统，方便统一监控页面



## local-lvm硬盘使用率监控

* 监控规则：被动调用，Uptime Kuma 定时访问 PVE 服务器的 8080端口，若返回 ok 则正常

* lvm_check.sh

  /root/TOOLS/lvm_http_server.py

  ```bash
  #!/bin/bash

  # 设置使用量阈值
  THRESHOLD=90

  # 初始化JSON输出
  output='{"status": "ok", "volumes": []}'

  # 使用文件描述符重定向来避免子 Shell 问题
  while read -r lv vg usage lsize pool; do
    # 去除空格和百分号
    usage=$(echo $usage | tr -d ' ' | tr -d '%')

    # 只处理 pool 为 data 的逻辑卷
    if [ "$pool" != "data" ]; then
      continue
    fi

    # 如果usage为空，跳过此逻辑卷
    if [ -z "$usage" ]; then
      continue
    fi

    # 检查usage是否为数字
    if [[ "$usage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      # 使用bc进行比较，避免浮点数比较问题
      usage_value=$(echo "$usage > $THRESHOLD" | bc -l)
      if [ "$usage_value" -eq 1 ]; then
        # 如果超过阈值，改变状态并添加详细信息到JSON
        output=$(echo "$output" | jq '.status = "fail"')
        output=$(echo "$output" | jq --arg lv "$lv" --arg vg "$vg" --arg usage "$usage" --arg lsize "$lsize" '.volumes += [{"lv": $lv, "vg": $vg, "usage": $usage, "lsize": $lsize}]')
      fi
    else
      echo "Warning: Invalid usage value for LV $lv in VG $vg: $usage" >&2
    fi
  done < <(lvs --noheadings -o lv_name,vg_name,data_percent,lv_size,pool_lv --units g --nosuffix)

  # 输出结果
  echo "$output"
  ```

* 搭建简易http服务器

  /root/TOOLS/lvm_http_server.py

  ```python
  from http.server import BaseHTTPRequestHandler, HTTPServer
  import subprocess

  class LVMCheckHandler(BaseHTTPRequestHandler):
      def do_GET(self):
          # 运行Shell脚本并获取输出
          result = subprocess.run(['/usr/local/bin/lvm_check.sh'], stdout=subprocess.PIPE)
          output = result.stdout.decode('utf-8')

          # 发送响应头
          self.send_response(200)
          self.send_header('Content-type', 'application/json')
          self.end_headers()

          # 发送脚本输出
          self.wfile.write(output.encode('utf-8'))

  # 启动HTTP服务器
  server_address = ('', 8080)  # 监听端口8080
  httpd = HTTPServer(server_address, LVMCheckHandler)
  print('Running server...')
  httpd.serve_forever()
  ```
* http服务器自动启动

  vim /etc/systemd/system/lvm_http.service

  ```ini
  [Unit]
  Description=LVM Check HTTP Service
  After=network.target

  [Service]
  ExecStart=/usr/bin/python3 /root/TOOLS/lvm_http_server.py
  Restart=always
  User=root

  [Install]
  WantedBy=multi-user.target
  ```

* 配置自动启动

  ```bash
  systemctl daemon-reload
  systemctl start lvm_http
  systemctl enable lvm_http
  ```

## 

## 网口速率是否为千兆速率（主动调用）

* 监控规则：主动调用，PVE 服务器主动调用 Uptime Kuma 接口，Uptime Kuma在规定时间内必须接收到状态为`up`的接口调用

* 检查网卡速率脚本

  /root/TOOLS/lan_speed_checker.sh

  ```bash
  #!/bin/bash

  # 使用 ethtool 获取网卡速率信息
  INTERFACE="enp2s0"
  SPEED=$(ethtool $INTERFACE | grep "Speed:" | awk '{print $2}')

  # 判断当前速率是否符合期望值（例如1000Mb/s）
  if [[ "$SPEED" == "1000Mb/s" ]]; then
      # 如果速率正常，返回HTTP状态码 200
      curl -s -o /dev/null -w "%{http_code}" http://192.168.1.1:3001/api/push/Hj1InlrzWd?status=up
  else
      # 如果速率异常，返回HTTP状态码 500
      curl -s -o /dev/null -w "%{http_code}" http://192.168.1.1:3001/api/push/Hj1InlrzWd?status=down
  fi
  ```

* 定时任务

  crontab -l

  ```bash
  PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

  * * * * * /root/TOOLS/lan_speed_checker.sh
  ```
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTEwNzM1MTQyODFdfQ==
-->
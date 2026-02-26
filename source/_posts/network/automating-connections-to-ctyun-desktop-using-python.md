---
title: 天翼云电脑永不休眠方法高科技版本（基于Python）
tags:
  - ctyun
  - python
  - chrome
  - 天翼云
  - 云电脑
published: true
hideInList: false
isTop: false
categories:
  - network
date: 2024-06-18 17:41:35
feature:
---
#### 原理：定期连接天翼云桌面（需小于1小时间隔）

##### 步骤一：获取请求数据

1. **打开Chrome浏览器的开发者工具**：
   - 在Chrome浏览器中按`F12`或右键选择`检查`打开开发者工具。

2. **访问并登录天翼云桌面**：
   - 访问`https://pc.ctyun.cn`，并使用你的账号登录云电脑。

3. **复制connect请求的curl命令**：
   - 在开发者工具中，选择`Network`标签，找到并点击名为`connect`的请求。
   - 右键点击该请求，选择`Copy as cURL (cmd)`。

4. **获取localStorage中的authData**：
   - 在开发者工具中，选择`Application`标签。
   - 在左侧栏中找到`Local Storage`并选择`https://pc.ctyun.cn`。
   - 找到`authData`键，复制其对应的值。

<!-- more -->

##### 步骤二：填充到Python脚本

将获取到的curl命令中的相关数据和localStorage中的`authData`值，复制到临时的记事本中，找到下面Python脚本所需字段，并
<!-- more -->
填充到以下Python脚本中：

```python
import requests
import hashlib
import time

# 配置参数（用户需要根据实际情况修改）
device_info = {
    "objId": "你的设备ID",  # 设备ID
    "objType": 0,  # 设备类型
    "osType": 15,  # 操作系统类型
    "deviceId": 60,  # 设备ID
    "deviceCode": "你的设备代码",  # 设备代码
    "deviceName": "你的设备名称",  # 设备名称
    "sysVersion": "你的系统版本",  # 系统版本
    "appVersion": "1.36.1",  # 应用版本
    "hostName": "你的主机名称",  # 主机名称
    "vdCommand": "",  # 虚拟桌面命令
    "ipAddress": "",  # IP地址
    "macAddress": "",  # MAC地址
    "hardwareFeatureCode": "你的硬件特征码"  # 硬件特征码
}

# 请求头中的一些参数
app_model_value = "2"
device_code_value = "你的设备代码"
device_type_value = "60"
request_id_value = "你的请求ID值"
tenant_id_value = "你的租户ID值"
userid_value = "你的用户ID值"
version_value = "201360101"
secret_key_value = "你的秘钥值"

# 动态生成时间戳
timestamp_value = str(int(time.time() * 1000))

# 创建签名字符串
signature_str = device_type_value + request_id_value + tenant_id_value + timestamp_value + userid_value + version_value + secret_key_value

# 使用MD5算法创建签名
hash_obj = hashlib.md5()
hash_obj.update(signature_str.encode('utf-8'))
digest_hex = hash_obj.hexdigest().upper()

# 准备请求头
headers = {
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'content-type': 'application/x-www-form-urlencoded',
    'ctg-appmodel': app_model_value,
    'ctg-devicecode': device_code_value,
    'ctg-devicetype': device_type_value,
    'ctg-requestid': request_id_value,
    'ctg-signaturestr': digest_hex,
    'ctg-tenantid': tenant_id_value,
    'ctg-timestamp': timestamp_value,
    'ctg-userid': userid_value,
    'ctg-version': version_value,
    'origin': 'https://pc.ctyun.cn',
    'priority': 'u=1, i',
    'referer': 'https://pc.ctyun.cn/',
    'sec-ch-ua': '"Google Chrome";v="125", "Chromium";v="125", "Not.A/Brand";v="24"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
}

# 设置API的URL和路径
url = "https://desk.ctyun.cn:8810/api/"
computer_connect = "desktop/client/connect"

# 发起POST请求连接云电脑
response = requests.post(url + computer_connect, data=device_info, headers=headers)

# 打印出云电脑的连接状态
print("云电脑连接状态：", response.json())
```

##### 步骤三：定时执行脚本

你可以使用以下方法定期执行脚本：

1. **Windows任务计划**：
   - 打开`任务计划程序`，创建一个新的任务。
   - 在`操作`选项卡中，选择`启动程序`，然后选择你的Python解释器和脚本路径。

2. **Linux Crontab**：
   - 打开终端，输入`crontab -e`。
   - 添加一行来定期运行脚本，例如每小时运行一次：
     ```
     0 * * * * /usr/bin/python3
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTQ0NjAxMDQyXX0=
-->
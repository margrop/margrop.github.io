---
title: PVE 磁盘巡检接入 Uptime Kuma——踩坑 404 的来龙去脉与最终脚本  
date: 2025‑05‑14T17:05:00Z  
tags: [Proxmox VE, LVM‑Thin, Uptime Kuma, Shell, Cron, 运维监控]
published: true
hideInList: false
feature: 
isTop: false
---


> **写在前面**  
> 前一篇文章教大家把 PVE 宿主机的 LVM‑Thin 用量推到 Uptime Kuma。  
> 有同学照做后 `curl` 推送却报 **404**。本文完整复盘原因、修正脚本，并给出 **可选升级方案**。零基础跟着做，保证一次成功。

----------

## 1 现象：`curl … 404`

```bash
curl -fsS --retry 3 \
     "${PUSH_URL}?status=up&msg=OK" \
     -H 'Content-Type: application/json' \
     --data-raw "$result"
# ↳ curl: (22) The requested URL returned error: 404
```

同一条 URL 用浏览器或 `curl GET` 又能收到：

```json
{"ok":true}
```

----------

## 2 原因：旧版 Uptime Kuma _只支持 GET/HEAD_ Push

一旦 `curl` 带 `--data-raw/-d`，HTTP 方法就变 **POST**，而 **Kuma ≤ 1.23.x** 的 Push 路由只注册了 GET/HEAD，因此直接 404。社区里已有多人反馈同样问题，GitHub Issue #3267 被标记为「feature‑request」至今未合并。([GitHub](https://github.com/louislam/uptime-kuma/issues/3267?utm_source=chatgpt.com "Allow http `POST` ing to the `push-monitor` · Issue #3267 - GitHub"))

Reddit 4 个月前的讨论同样验证了“POST 会 404，暂无官方解决方案”。([Reddit](https://www.reddit.com/r/UptimeKuma/comments/1hx8lfh/can_uptime_kuma_push_monitors_support_post/?utm_source=chatgpt.com "Can Uptime Kuma Push Monitors Support POST Requests? - Reddit"))

----------

## 3 两条出路

方案

思路

适用场景

**A. 改回纯 GET**

不带正文，用 URL 参数（最稳妥）

不想折腾 Kuma 升级

**B. 升级到 2.x β 版 / 自行打补丁**

未来版本预期会支持 POST；也可用反向代理把 POST 转 GET

愿意测试新版本、或必须上传大量 JSON 正文

> 下文主讲 **方案 A**，保证 5 分钟之内搞定。方案 B 放在文末扩展阅读。

----------

## 4 最终脚本（纯 GET 版）

### 4.1 配置文件不变

```bash
# /etc/lvm_check.conf
PUSH_URL="http://192.168.102.146:3001/api/push/E94XDnl557"
```

### 4.2 推送脚本 `/usr/local/bin/lvm_kuma_push.sh`

```bash
#!/bin/bash
# 向 Uptime Kuma 发送 GET 心跳，兼容旧版不支持 POST 的限制
source /etc/lvm_check.conf
[ -z "$PUSH_URL" ] && { echo "缺少 PUSH_URL"; exit 1; }

json="$(/usr/local/bin/lvm_check.sh)"
status=$(echo "$json" | jq -r '.status')
encoded_json=$(printf '%s' "$json" | jq -sRr @uri)  # URL‑encode 详情

if [ "$status" = "ok" ]; then
  curl -fsS --retry 3 \
       "${PUSH_URL}?status=up&msg=OK&details=${encoded_json}"
else
  problem=$(echo "$json" | jq -c '.volumes')
  encoded_prob=$(printf '%s' "$problem" | jq -sRr @uri)
  curl -fsS --retry 3 \
       "${PUSH_URL}?status=down&msg=${encoded_prob}&details=${encoded_json}"
fi
```

-   **完全去掉** `--data-raw` 和 `Content-Type`，`curl` 保持 GET。
    
-   把原本想 POST 的 JSON 用 `details=` 参数 URL‑encode 后附在尾部；在 Kuma 的「Maintenance Log」里依然能看到完整内容。
    

### 4.3 Cron 不变

```cron
*/5 * * * * /usr/local/bin/lvm_kuma_push.sh >/dev/null 2>&1
```

----------

## 5 验证步骤

1.  **手动执行脚本**
    
    ```bash
    /usr/local/bin/lvm_kuma_push.sh
    ```
    
    在 Kuma web 界面应立即出现一次绿色 **Up** 心跳。
    
2.  **模拟磁盘告警**
    
    -   临时把 `THRESHOLD=90` 改成 `1` → 再执行脚本
        
    -   Kuma 立刻标红，并显示 `msg` 为 JSON 里触发的卷列表
        
    -   改回 90，空间正常后再次 Up
        

----------

## 6 扩展阅读：想用 POST 怎么办？

1.  **升级到 Kuma 2.x β**  
    2.x 开始重构后端，社区 PR 中已有对 Push 路由的增强；在正式 GA 前可试用 β 版（自行评估风险）。
    
2.  **反向代理转发**  
    Nginx 片段示例：
    
    ```nginx
    location /api/push/ {
        proxy_pass_request_body off;
        proxy_pass http://kuma:3001;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-Method $request_method;
    }
    ```
    
    搭配 Lua / middleware 把 POST 改写成 GET（参考 alertmanager‑kuma‑push 项目）。
    

----------

## 7 总结一张图

```text
lvm_check.sh  ──>  lvm_kuma_push.sh (GET)  ──>  Uptime Kuma Push Monitor
     ↑ JSON              ↑ URL 参数
     └─────── cron */5 ───────┘
```

-   **404 根因**：旧版 Kuma Push Monitor 不认 POST；去掉正文即可。
    
-   **零依赖**：脚本仍仅需 `jq`、`bc`、`curl`。
    
-   **未来可扩展**：待 Kuma 官方支持 POST 后，再把 `--data-raw` 加回来即可。
    

至此，PVE 宿主机磁盘巡检成功接入 Uptime Kuma，并解决了 404 大坑。祝各位再也不怕凌晨磁盘打满！
<!--stackedit_data:
eyJoaXN0b3J5IjpbMTUyOTc1NjUxN119
-->
---
title: PVE 宿主机磁盘空间监控——从踩坑到接入 Uptime Kuma 的完整小白教程  
date: 2025‑05‑14T16:10:00Z  
tags: [Proxmox VE, LVM‑Thin, Uptime Kuma, Shell, Cron, 运维监控]

---
> **目标读者**  
> 这篇文章写给刚刚接触 Proxmox VE（简称 **PVE**）且希望“按步骤照做就能跑”的同学。整篇内容力求：
> 
> -   解释 _为什么_ 会遇到问题
>     
> -   每一步都给出 **完整命令**
>     
> -   出错时给出 **排查思路**
>     

----------

## 0 背景——到底出啥问题？

-   PVE 官方安装向导默认把虚拟机硬盘建在 **LVM‑Thin** 池（常见名字：`pve/data`）
    
-   LVM‑Thin 支持“超额分配”——给 VM 分了 500 G，其实物理磁盘只占用写入量
    
-   如果宿主机上的 LVM‑Thin 池快满了，最直接的症状是：
    
    -   宿主机无法写日志、Web 界面打不开
        
    -   虚拟机也可能报各种 I/O 错误甚至宕机
        

**结论**：一定要实时监控 `data_percent`（池已用百分比）。

----------

## 1 总体思路

步骤

作用

技术

A

写一个 **检查脚本** `lvm_check.sh`：返回 JSON，判定 OK / FAIL

Shell + jq + bc

B

写一个 **推送脚本** `lvm_kuma_push.sh`：把结果送到 Uptime Kuma

Shell + curl

C

在 Uptime Kuma 新建 **Push 类型** 监控

Web GUI

D

用 **cron** 定时执行推送脚本

Cron

----------

## 2 准备环境

1.  **登录宿主机**（不是虚拟机！），确保拥有 root 权限。
    
2.  安装用到的工具：
    

```bash
sudo apt update
sudo apt install -y jq bc curl
```

3.  确认宿主机确实在用 LVM‑Thin：
    

```bash
lvs -o lv_name,vg_name,pool_lv,data_percent --noheadings
```

若能看到 `pve/data` 且 `pool_lv` 字段为 `data`，就符合本文条件。

----------

## 3 步骤 A：编写检查脚本 `/usr/local/bin/lvm_check.sh`

```bash
sudo nano /usr/local/bin/lvm_check.sh
```

```bash
#!/bin/bash
# 判断 LVM‑Thin 池用量是否超过阈值（默认 90%）
THRESHOLD=90
output='{"status":"ok","volumes":[]}'

while read -r lv vg usage lsize pool; do
  usage=$(echo "$usage" | tr -d ' %')
  [ "$pool" != "data" ] && continue
  [ -z "$usage" ] && continue

  if [[ "$usage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    if [ "$(echo "$usage > $THRESHOLD" | bc -l)" -eq 1 ]; then
      output=$(echo "$output" | jq '.status="fail"')
      output=$(echo "$output" | jq --arg lv "$lv" --arg vg "$vg" \
                                   --arg usage "$usage" --arg lsize "$lsize" \
          '.volumes += [{"lv":$lv,"vg":$vg,"usage":$usage,"lsize":$lsize}]')
    fi
  fi
done < <(lvs --noheadings -o lv_name,vg_name,data_percent,lv_size,pool_lv \
             --units g --nosuffix)

echo "$output"
```

```bash
sudo chmod +x /usr/local/bin/lvm_check.sh
```

**手动测试**

```bash
/usr/local/bin/lvm_check.sh | jq
```

-   `status":"ok"` → 磁盘健康
    
-   `status":"fail"` → JSON 里会列出超限卷
    

----------

## 4 步骤 C：在 Uptime Kuma 创建 Push 监控

1.  打开 Uptime Kuma Web 界面 → **“New Monitor”**
    
2.  选择 **Type = Push**
    
3.  取个名字（示例：`PVE‑LVM‑Disk`）
    
4.  设置 **Heartbeat Interval = 300 seconds**（可改）
    
5.  保存后，记录系统生成的 **Push URL**，形如：
    

```
https://uptime.example.com/api/push/abcdef1234567890
```

----------

## 5 步骤 B：推送脚本把结果发给 Kuma

### 5.1 将 Push URL 写进配置

```bash
echo 'PUSH_URL="https://uptime.example.com/api/push/abcdef1234567890"' \
  | sudo tee /etc/lvm_check.conf
```

### 5.2 新脚本 `/usr/local/bin/lvm_kuma_push.sh`

```bash
sudo nano /usr/local/bin/lvm_kuma_push.sh
```

```bash
#!/bin/bash
# 向 Uptime Kuma 推送巡检结果
source /etc/lvm_check.conf
[ -z "$PUSH_URL" ] && { echo "缺少 PUSH_URL"; exit 1; }

result="$(/usr/local/bin/lvm_check.sh)"
status=$(echo "$result" | jq -r '.status')

if [ "$status" = "ok" ]; then
  curl -fsS --retry 3 "${PUSH_URL}?status=up&msg=OK" \
       -H 'Content-Type: application/json' \
       --data-raw "$result"
else
  problem=$(echo "$result" | jq -c '.volumes')
  curl -fsS --retry 3 "${PUSH_URL}?status=down&msg=${problem}" \
       -H 'Content-Type: application/json' \
       --data-raw "$result"
fi
```

```bash
sudo chmod +x /usr/local/bin/lvm_kuma_push.sh
```

**验证一次**

```bash
/usr/local/bin/lvm_kuma_push.sh
# 不报错即推送成功，Kuma 上应出现一次心跳
```

----------

## 6 步骤 D：用 cron 定时执行

```bash
sudo crontab -e
```

在文件末尾添加：

```cron
*/5 * * * * /usr/local/bin/lvm_kuma_push.sh >/dev/null 2>&1
```

> **含义**：每 5 分钟执行一次推送，与 Kuma 中的 300 s 间隔保持一致。

保存退出后，可用 `sudo systemctl restart cron` （Debian 12）确保 cron 服务正在运行。

----------

## 7 如何验证整条链路？

1.  等 5‑10 分钟，看 Uptime Kuma 的 _**PVE‑LVM‑Disk**_ 是否已变绿（Up）。
    
2.  手动制造高使用率（或临时把脚本里 `THRESHOLD=90` 改成 `1`）再跑一次推送：
    
    -   Kuma 立即变红（Down），说明告警链路 OK。
        
    -   改回 90 或释放空间，再推送一次，状态恢复 Up。
        

----------

## 8 常见报错与排查

报错/现象

原因 & 解决

`jq: command not found`

执行 `sudo apt install -y jq`

Stderr: `curl: (28) Connection timed out`

宿主机到 Kuma 网络不通；先 `curl -I $PUSH_URL` 测试

Kuma 页面显示 “No Heartbeat”

1) cron 未生效；2) PUSH_URL 写错；3) 脚本报错未推送（查 `/var/log/syslog`）

`status":"fail"` 但 `.volumes` 为空

宿主机用的不是 LVM‑Thin；请用 `zfs list` 或其它方式监控

----------

## 9 后续可拓展

想法

方向

图形化趋势

Kuma 的「Status Page」仅展示 Up/Down，可把 JSON 转 Prometheus 指标画曲线

邮件/钉钉通知

在 Kuma 的 **Notification** 里配置即可，脚本不用改

systemd‑timer

不喜欢 cron，可写 `lvm_kuma_push.timer`，精度更高

----------

## 10 总结

1.  **最小化依赖**：只有 `jq bc curl`，脚本全放宿主机，虚拟机端零改动。
    
2.  **告警及时**：LVM‑Thin 池超过阈值立刻让 Uptime Kuma 变红并通知。
    
3.  **步骤清晰**：新手按本文复制‑粘贴即可复现，失败场景也给出了排错思路。
    

希望这篇笔记能帮你 **把“磁盘爆满恐惧”扼杀在摇篮里**。如果你有更优雅的做法或遇到别的坑，欢迎评论区交流！
<!--stackedit_data:
eyJoaXN0b3J5IjpbMTUwMzkzOTQ0NV19
-->
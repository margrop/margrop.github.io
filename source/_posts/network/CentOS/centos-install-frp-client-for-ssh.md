---
title: 'CentOS安装Frp客户端，可使用SSH'
date: 2021-01-23 17:22:58
tags: [centos,install,frps,frpc,nohup,linux,client,ssh]
published: true
hideInList: false
feature: 
isTop: false
---
# 下载并解压Frp
* 最新Frp下载地址：<https://github.com/fatedier/frp/releases/>
```bash
mkdir ~/frp
cd ~/frp
wget https://github.com/fatedier/frp/releases/download/v0.35.0/frp_0.35.0_linux_amd64.tar.gz
tar -xvzf frp_0.35.0_linux_amd64.tar.gz
```

<!-- more -->

# 删除服务器相关文件
```bash
cd ~/frp/frp_0.35.0_linux_amd64
rm -rf frps*
```
 
# 配置Frp客户端
* 需自行修改`server_addr`,`server_port`,`local_port`,`remote_port`以及`客户端名称`
```bash
vi frpc.ini

[common]
server_addr = blog.margrop.net
server_port = 2000
 
[SSH-VM-CENTOS]
type = tcp
local_port = 22
remote_port = 2022
```

# 启动FRP服务
```bash
cd ~/frp/frp_0.35.0_linux_amd64
nohup ./frpc &
tail -f nohup.out
```
 
# (可选，请自行修改)加入免认证公钥
```bash
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyq1pB5aF0w6ps4OzwQl1C8uP41Iq7J+gqylLMXkoESrTUVhH1+irHuImxi2At886sO7x9s+b4jhRZoJZpZURPU4UmzUEBHKoXlqOf9eO//GtUita2AaPFw5tc0YgLPrgnO+z5MKfjo20aoJtVBvleRA/0YJcWy1a6ufXa8944D8a1Dirc9uVNR5QjKVFRbQt/twLkLdFB6t16HCwISKCVI56DcJOoY2g7mXI8clKaESeB+ANIhSKJclPwjoC6P0pHFfgqNauxC+0xugx3W2ZSIkVhdZu1L7iKvzXXPiETjPQA6qMjp/1dY2WU49Lf+wDOQplCy4HLq7QqNNVSzIBGw== Administrator@PCOS-1407251925" >> ~/.ssh/authorized_keys
```

# 设置自动启动
```bash
cat /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
echo "cd /root/frp/frp_0.35.0_linux_amd64" >> /etc/rc.d/rc.local
echo "nohup /root/frp/frp_0.35.0_linux_amd64/frpc & ">> /etc/rc.d/rc.local
```
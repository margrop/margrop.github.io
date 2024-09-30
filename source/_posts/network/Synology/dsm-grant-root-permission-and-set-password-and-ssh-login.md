---
title: '群晖6.17最新获取root权限，设置root密码和SSH免登录'
date: 2021-02-10 20:40:26
tags: [dsm,root,ssh]
published: true
hideInList: false
feature: 
isTop: false
---
# 一、开启SSH功能
* `控制面板`->`终端机和SNMP`里，开启`SSH`功能
  
# 二、登陆群晖的SSH，用系统默认用户登陆
* 我这里是`admin`，所以我输入以下命令，`admin`和`IP地址`修改为你的
```bash
ssh admin@192.168.1.5
```

<!-- more -->

# 三、登陆后输入以下命令切换至root账号，这时还需在输入一次你的群晖登陆密码
```bash
sudo -i
```

# 四、输入以下命令进入到ssh的目录，给sshd_config赋予755的权限
```bash
cd /etc/ssh
chmod 755 sshd_config
```

# 五、修改config配置文件内容
输入
```bash
vi /etc/ssh/sshd_config
```
点击`i`键进入编辑模式，找到`#PermitRootLogin prohibit password`
更改为`PermitRootLogin yes`,注意前面的`#`号不要
按`Esc`键退出编辑模式，输入`:wq`保存

# 六、增加SSH公钥
* 请改成自己的`SSH`公钥
```bash
cd ~
mkdir .ssh
echo ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAyq1pB5aF0w6ps4OzwQl1C8uP41Iq7J+gqylLMXkoESrTUVhH1+irHuImxi2At886sO7x9s+b4jhRZoJZpZURPU4UmzUEBHKoXlqOf9eO//GtUita2AaPFw5tc0YgLPrgnO+z5MKfjo20aoJtVBvleRA/0YJcWy1a6ufXa8944D8a1Dirc9uVNR5QjKVFRbQt/twLkLdFB6t16HCwISKCVI56DcJOoY2g7mXI8clKaESeB+ANIhSKJclPwjoC6P0pHFfgqNauxC+0xugx3W2ZSIkVhdZu1L7iKvzXXPiETjPQA6qMjp/1dY2WU49Lf+wDOQplCy4HLq7QqNNVSzIBGw== Administrator@PCOS-1407251925 >> ~/.ssh/authorized_keys
```

# 七、重启群晖
在`Web界面`重启，或者直接在输入`reboot`

# 八、重启完成再次以系统默认账户登录群晖SSH
* 我这里是admin，所以我输入以下命令，`admin`和`IP地址`修改为你的
```bash
ssh admin@192.168.1.5
```

# 九、切换至root账号
* 输入以下命令，这时还需在输入一次你的群晖登陆密码
```bash
sudo -i
```

# 十、修改root默认密码
* 输入下面命令，`xxx`改为你要设置的密码，回车没有任何提示即可
```bash
synouser --setpw root xxx
```

# 十一、这时再重新以root权限就可以登陆到ssh了
* `IP地址`记得改为你群晖的`IP地址`哦
```bash
ssh root@192.168.1.5
```
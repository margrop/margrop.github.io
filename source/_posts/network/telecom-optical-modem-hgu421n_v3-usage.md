---
title: 电信光猫 HGU421N_V3使用
tags:
  - telecom
  - modem
  - 电信
  - 光猫
published: true
hideInList: false
isTop: false
categories:
  - network
date: 2021-09-02 10:59:03
feature:
---
# Note:
```
Ethernet port 4: 1000Mb/s, others 10/100Mb/s
Password of TTY might NOT be 以用户名：admin，密码：v2mprt 登录
Any powerful Route compatible  with ChinaTelecom EPON and has  2 1000Mb/s ports at least?
```

# e8-C终端用户使用手册:
<http://js.189.cn/support/help_support/images/e8help/e8-cHelpHandbook.pdf>

# 产品技术规范:
<http://www.huaqinworld.com/productshow.aspx?id=409>

# 华勤HGU421N v3.0 宽带猫破解:
<https://bbs.et8.net/bbs/showthread.php?t=1309600>


<!-- more -->


## pplc #1 旧 2015-01-02, 17:39:43 默认 新版华勤HGU421N V3光猫破解

最新在网上找了一些老版的HGU421N V3破解资料，参照之下破解了新版的HGU421N V3，并且上面还带着IPTV。破解光猫版本如下
```
Bootbase Version : V1.04
Firmware FakeVersion : 301WFA0AE0SH
Firmware RealVersion : 3.01(WFA.0)b3_20140513
Hardware Version : V3.0
Vendor : huaqin
Model Name : HGU421N v3(V3.0)
```
## 第一步：获取telecomadmin帐号密码
这里使用USB转TTL板子，以串口通信接入电路板。USB转TTL板子淘宝价格3-8元，注意需要3条杜邦线。将光猫开壳，可以看见1个5针插座，其中有1针缺针，就以缺针的为2做针序定位。

1. GND 接USB转TTL板的GND
2. 缺针 （不接线）
3. RXD 接USB转TTL板的TXD
4. TXD 接USB转TTL板的RXD
5. 有针 （不接线）

注意接线时光猫断电，光纤断不断无所谓的，串口通信软件最好使用putty，我先用了超级终端，没有反应，后来putty搞通了，也没有再用超级终端试，串口速率设置为115200，USB转TTL使用哪个串口就只有自己搞定了。

以用户名：admin，密码：v2mprt 登录
```
dumpnvram 可以看见telecomadmin的密码（这个命令只有新版有效）
dumpcfg也可以看见telecomadmin的密码（这个对老版也有效的），但这条命令显示数据太多，建议在进入putty前设置显示全log，进入就做这条命令，做好就退出查log。
wanlimit set mode 0，直接将计算机数量限制关掉，网上的资料都是用wanlimit set totalnum 10 来增加计算机数量，但这样还是会消耗光猫的CPU资源来检测计算机数量，且这个检测消耗的CPU资源还不少了，会影响网络速度，所以关掉是最好的。
```
再开个Telenet的后门，以防电信将telecomadmin密码改掉，又要重新开壳TTL通讯
```
localservice telnet enable 打开telnet服务
localservice ftp enable 打开ftp服务，FTP根目录在/mnt
```
最后记得键入save命令，进行保存。
新版的这里别担心开了服务WAN可以访问，输入localservice就能知道为什么了。老版的这里需要留意WAN可以访问的问题。
```
telnet 用户名：e8telnet 密码：e8telnet
ftp 用户名：e8ftp 密码：e8ftp
```
接下去就可以断电，拔下TTL线，光猫复原装盒了
然后就可以以web方式telecomadmin帐号访问了，接下去就发现无法删除TR069协议了，这个是新版在光猫的web服务中做的限制，如果不需要删掉TR069可以直接跳过。

## 第二步：删除TR069

以IE登录光猫IP，用telecomadmin帐号登录，点击”网络”->”宽带设置”, “连接名称”选择TR069那个，这时下面的删除按钮会变灰，用鼠标右键点击删除按钮上面的白色的网页空白处，在弹出菜单中点击”查看源文件”，这时会弹出一个BroadBund[1]的文本文件，里面全是HTML源码，

找到 var allowTR069WANEdit = ‘0’; 这行将其中的0改成1
再找到 loc = “eponwan.cmd?action=remove&rmLst=” + rmLst; 这行，可以以eponwan.cmd?action=remove为关键字查找，在eponwan前面加入http://192.168.1.1/，改好的行参考如下，这里的IP地址就是光猫的IP地址
```
loc = “http://192.168.1.1/eponwan.cmd?action=remove&rmLst=” + rmLst;
```
将此文件以Broadbund.html存盘，注意这时别关IE，因为上面还有session信息，你关了IE那session就失效了，再以IE打开这个存盘的html文件，IE会提示ActiveX运行等安全信息，选择”允许运行”，在其中”连接名称”选择TR069这行，千万别选错了，然后点击下面的”删除”按钮，就能删除TR069了。

这里的操作需要注意的是速度，因为有一个session参数，操作速度超过session timeout时间操作就失败了，这个时间一般都有5-10分钟的，这个只要熟悉一下上面的操作步骤不成问题的，当然复制session值也是可以，这里就不描述了。删了tr069电信就没有办法远程管理这个光猫了。

Internet连接可以使用Route模式，就以光猫未路由器使用了，也可以设置Bridge模式，这样就需要在安装自己的路由器了。IPTV使用的是Bridge模式，且使用了VLAN TAG模式通讯，而Internet是使用VLAN Untag通讯的，所以在使用IPTV的端口上，如Internet使用路由模式，其实是可以复合走Internet和IPTV的，且是互不干扰的。


---
title: '上海贝尔 E-140W-P，光猫配置'
date: 2021-12-04 13:46:58
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# Telnet
telnet 命令：telnet 192.168.1.1
telnet 账号密码：telnetadmin / telnetadmin

# 默认密码
telecomadmin
nE7jA%5m
telnet密码
telnetadmin / telnetadmin

<!-- more -->

# 硬件配置
* BCM6838芯片支持接口及功能如下
1、4个内置千兆PHY
2、内置GPON MAC，EPON MAC,
3、MIPS 32位处理器,400M双核(64K×2指令缓存,32K数据缓存)
4、内置voip处理器
5、2路支持802.11n??WLAN PCIE接口，可以外接PCIE AP，或者USB型 AP
6、2路USB 2.0接口，1路可以作为HOST，1路可以配置为HOST或者DEVICE。
7、DDR3控制器，最大支持4Gbit
8、NAND控制器，最大支持2Gbit
9、安全引擎:支持IPSEC,SSL硬件加速

* Cortina8032
1、EPON MAC + 需要外接PHY
2、内置ARM926EJ-S*32位处理器(16K指令缓存16K数据缓存)
3、基于以太网的接口可用于外接VOIPSoC??
4、串口：串行flash，EEPROM；并口：并行flash最大128M

# 后台管理页面，必须先使用 telecomadmin 账号登录

ps. 用超级用户登录后，http://192.168.1.1/backupsettings.html，该网址能备份出未加密的配置文件。用记事本打开修改后，可以用 http://192.168.1.1/updatesettings.html 这个页面写回网关。

* 用超级用户登录后，在浏览器输入以下网址。

http://192.168.1.1/scsrvcntr.html 该页面能开启telnet，SSH，FTP等各种服务。
http://192.168.1.1/dumpmdm.cmd 该页面能显示当前配置。

* 注意：F450G必须超级用户登录，有些设备普通用户登录也行。
导出配置页面：http://192.168.1.1/backupsettings.html
导入配置页面：http://192.168.1.1/updatesettings.html
服务访问控制：http://192.168.1.1/scsrvcntr.html
工厂模式页面：http://192.168.1.1/factorymode.html   (工厂模式下可修改MAC等参数)
版本信息页面：http://192.168.1.1/test_version.html
显示当前配置：http://192.168.1.1/dumpmdm.cmd
翻帖子翻来的，仅作记录

* telnet 输入show mdm config 就能输出配置文件信息

* 各功能页面
http://192.168.1.1/scsrvcntr.html 该页面能开启telnet，SSH，FTP等各种服务。
http://192.168.1.1/dumpmdm.cmd 该页面能显示当前配置。
http://192.168.1.1/resetdefault.html 清空所有信息、恢复出厂
http://192.168.1.1/pluginManage.html 打开插件管理页面
http://192.168.1.1/test_version.html 确定设备固件版本 有运行时间
http://192.168.1.1/register.cmd?registered=1 关闭LOID注册界面
http://192.168.1.1/upload.html  固件升级
http://192.168.1.1/resetdefault.html 回复出厂
http://192.168.1.1/factorymode.html  工程模式
http://192.168.1.1/backupsettings.html 导出配置文件 backupsettings.conf
http://192.168.1.1/updatesettings.html 导入配置文件
http://192.168.1.1/skipreg.html 手动打开\关闭上网权限

# 救砖头改gpon
启动救砖头 用ttl线，按住光猫上的复位键加电，灯亮一直等灯灭，应该可以进入cfe， 进入cfe，输入：s SfCfgName ct/asb-shanghai-epon-sip-sgw ，回车，输入：r，回车，重启
* 改epon
cfe s SfCfgName sct/asb-shanghai-epon-sip-sgw
* 改gpon
s SfCfgName ct/asb-jiangsu-gpon-h248-sgw
* 配置调用
GPON SIP 设置成 ct/asb-sip-sgw 系统版本自动调用固件内部 ASB_G140WV1.0S 系统段模块启动,
GPON H248 设置 ct/asb-h248-sgw 系统版本自动调用 ASB_G140WV1.0M 系统段模块启动
EPON SIP设置 ct/asb-sip-sgwepon系统版本自动调用 ASB_E140WV1.0S 系统段模块启动
EPON H248 设置 ct/asb-h248-sgwepon 系统版本自动调用 ASB_E140WV1.0M 系统段模块启动
* 刷江苏1.1s，
配置文件调用
江苏:ASB_G140WV1.0S ct/asb-jiangsu-gpon-h248-sgw
江苏:ASB_G140WV1.0S ct/asb-jiangsu-gpon-sip-sgw
ct/asb-jiangsu-2f0:ASBRG221O-NP_V1.0T_JS1402
ct/asb-jiangsu-epon-h248-sgw:ASBE-140W-P_V1.0S_JS1412
ct/asb-jiangsu-epon-sip-sgw :ASBE-140W-P_V1.0S_JS1412
ct/asb-jiangsu-gpon-h248-sgw:ASB_G140WV1.0S
* ttl查询超级密码
1. ttl线连接 tx  rx 反接
2. 编程器连接的ttl线 先安装usb转ttl驱动 然后连接ttl线 编程器的驱动不一样 例如ch341a 需要拔掉跳帽 默认是编程器模式
3. 在设备管理器里把 位/秒设置为 115200  流控制 x/on x/off 其他默认
4. 超级终端工具连接或者securecrt 也要设置与步骤3一样
5. 光猫接入电源 软件提示连接开始跑启动参数  等看到 RV SIP Stack verison xxxx successfully 按 enter键
次数输入账号密码登陆 注：输入密码的时候是看不见的
6. 出现#s304 或者xx#时 可以输入 show mdm config 列出配置文件
7. 截获配置文件保存为txt  查找X_CT-COM_TeleComAccount 字段下password 极为超级密码
# shell 部分命令
* 查cpu 占用 linuxshell sysinfo
cpm {“RPCMethod”:”UnInstall”,”Plugin_Name”:”osgid”}  ttl 杀虚拟机服务
* mdm  配置
A、破解打开网页自动跳转LOID注册页面（适用于手工配置，无法LOID注册的同学）
mdm set InternetGatewayDevice.X_CT-COM_UserInfo Status 0
mdm set InternetGatewayDevice.X_CT-COM_UserInfo Result 1
B、破解最大用户数““““`
mdm set InternetGatewayDevice.Services.X_CT-COM_MWBAND TotalTerminalNumber 32
mdm set InternetGatewayDevice.Services.X_CT-COM_MWBAND Mode 0 破解无限制
C、telnet被关后进TTL重新打开及设置telnet用户名密码
mdm set InternetGatewayDevice.DeviceInfo.X_CT-COM_ServiceManage TelnetEnable TRUE
mdm set InternetGatewayDevice.DeviceInfo.X_CT-COM_ServiceManage TelnetUserName root
mdm set InternetGatewayDevice.DeviceInfo.X_CT-COM_ServiceManage TelnetPassword admin
D、查看telecomadmin帐号的密码
show mdm InternetGatewayDevice.DeviceInfo.X_CT-COM_TeleComAccount
E、无论进行了任何指令设置，需要使用以下命令保存mdm配置!
mdm save
# 有虚拟机最小内存方案
shanghai-epon模式,telnet下不插光口使用cpm命令回车没有任何反应,插件管理页面可以关闭4个插件,此时内存占用为23******.悦me界面内存占用数为30%.再改guangdong-epon,恢复出厂后4个插件任然为关闭状态,此时内存占用为25*****.悦me界面内存占用数为30%.时间关系,未长时间采取数值进行比对.
综上,chongqing-epon内存占用数为15-17****,是测试中内存占用略小的方案.
* PS1:
如果担心被运营商重置密码，可以删除TR069(前提是你要懂得手动设置，不需要下发配置)。删除方法是在相关页面按F12，找到TR069的项，把“删除按钮”中的DISABLED全改为ENABLED，然后就可以删除。如有需要可以稍后补充
* PS2:
在上面第四步中还可以修改连接终端上限：mdm set InternetGatewayDevice.Services.X_CT-COM_MWBAND TotalTerminalNumber XX（此处为终端上限），记得最后输入mdm save保存 

# 参考文章
<http://www.chinadsl.net/thread-125305-1-1.html>
<https://idc.fantasysky.net/whmcs/index.php?rp=/knowledgebase/7/%E6%82%A6me%E5%85%89%E7%8C%AB---%E8%B4%9D%E5%B0%94---E-140W-P-%E7%9A%84-Telnet-%E5%BC%80%E5%90%AF%E6%96%B9%E5%BC%8Fand%E7%94%A8%E6%88%B7and%E5%AF%86%E7%A0%81.html>
<https://www.bilibili.com/read/cv9188553>



---
title: 自定义LEDE路由器KoolProxyR屏蔽广告规则，20200705
tags:
  - lede
  - router
  - adblock
  - rules
  - 广告屏蔽
  - 软路由
  - koolproxy
  - koolproxyr
published: true
hideInList: false
isTop: false
categories:
  - network
  - router
date: 2021-01-15 15:05:48
feature:
---
# 如何安装KoolProxyR
* 参考[KoolProxyR项目官网](https://github.com/user1121114685/koolproxyR)
> 在SSH中执行如下代码实现在线安装。（请全部复制）
```
wget -4 -O /tmp/KoolProxyR_install.sh https://shaoxia1991.coding.net/p/koolproxyr/d/koolproxyr/git/raw/master/KoolProxyR_install.sh && chmod 777 /tmp/KoolProxyR_install.sh && sh /tmp/KoolProxyR_install.sh
```

# 广告屏蔽规则
> 下面是我自己使用的路由器广告屏蔽规则
> 基于软路由`LEDE`，`KoolProxyR`的自定义规则中使用。

<!-- more -->

```
! https://gist.github.com/itspig/e22bd240cff35fbb4b29fafd2539de27
api.ad.xiaomi.com
sdkconfig.ad.xiaomi.com
ad.mi.com
ad.xiaomi.com
ad1.xiaomi.com

adv.sec.miui.com
test.ad.xiaomi.com
new.api.ad.xiaomi.com

cdn.ad.xiaomi.com
e.ad.xiaomi.com
test.new.api.ad.xiaomi.com

ssp.ad.xiaomi.com
o2o.api.xiaomi.com

! tcpdump

api.cupid.ptqy.gitv.tv

! others

stat.pandora.xiaomi.com
upgrade.mishop.pandora.xiaomi.com
logonext.tv.kuyun.com
config.kuyun.com
api.io.mi.com
mishop.pandora.xiaomi.com
dvb.pandora.xiaomi.com
de.pandora.xiaomi.com
data.mistat.xiaomi.com
jellyfish.pandora.xiaomi.com
!gallery.pandora.xiaomi.com
o2o.api.xiaomi.com
bss.pandora.xiaomi.com
gvod.aiseejapp.atianqi.com

!屏蔽自动更新和安装有品
package.cdn.pandora.xiaomi.com
package.box.xiaomi.com
ota.cdn.pandora.xiaomi.com

!nPlayer Lite屏蔽广告
rayjump.net
adservice.google.com
ads.yahoo.com
mzstatic.com
app-measurement.com
moatads.com
play.googleapis.com
iid.googleapis.com

!iPad屏蔽广告
googlevideo.com
googleusercontent.com
gstatic.com
googleads.g.doubleclick.net
googlesyndication.com
g.doubleclick.net
snssdk.com
sgsnssdk.com
app-measurement.com
pstatp.com
ctobsnssdk.com
umeng.com

!乐播投屏广告
adeng.hpplay.cn
adcdn.hpplay.cn
sl.hpplay.cn
rp.hpplay.cn
hpplay.com.cn

!小米相关广告
a.stat.xiaomi.com
a.union.mi.com
abtest.mistat.xiaomi.com
adinfo.ra1.xlmc.sec.miui.com
adv.sec.miui.com
api.ad.xiaomi.com
api.ra2.xlmc.sec.miui.com
api.tuisong.baidu.com
api.tw06.xlmc.sec.miui.com
app01.nodes.gslb.mi-idc.com
app02.nodes.gslb.mi-idc.com
app03.nodes.gslb.mi-idc.com
applog.uc.cn
beha.ksmobile.com
bss.pandora.xiaomi.com
calopenupdate.comm.miui.com
cdn.ad.xiaomi.com
cm.p4p.cn.yahoo.com
cm066.getui.igexin.com
connect.rom.miui.com
data.mistat.xiaomi.com
e.ad.xiaomi.com
etl.xlmc.sandai.net
fcanr.tracking.miui.com
fclick.baidu.com
get.sogou.com
hm.xiaomi.com
hub5pn.wap.sandai.net
idx.m.hub.sandai.net
image.box.xiaomi.com
info.analysis.kp.sec.miui.com
info.sec.miui.com
logupdate.avlyun.sec.miui.com
m.bss.pandora.xiaomi.com
m.irs01.com
m.sjzhushou.com
master.wap.dphub.sandai.net
mdap.alipaylog.com
migc.g.mi.com
migcreport.g.mi.com
migrate.driveapi.micloud.xiaomi.net
mis.g.mi.com
mlog.search.xiaomi.net
new.api.ad.xiaomi.com
notice.game.xiaomi.com
nsclick.baidu.com
o2o.api.xiaomi.com
p.alimama.com
pdc.micloud.xiaomi.net
ppurifier.game.xiaomi.com
pre.api.tw06.xlmc.sandai.net
r.browser.miui.com
reader.browser.miui.com
report.adview.cn
resolver.gslb.mi-idc.com
resolver.msg.xiaomi.net
sa.tuisong.baidu.com
sa3.tuisong.baidu.com
sdk.open.phone.igexin.com
sdk.open.talk.gepush.com
sdk.open.talk.igexin.com
sdkconfig.ad.xiaomi.com
sec-cdn.static.xiaomi.net
sec.resource.xiaomi.net
security.browser.miui.com
sg.a.stat.mi.com
staging.admin.e.mi.com
test.ad.xiaomi.com
test.api.xlmc.sandai.net
test.e.ad.xiaomi.com
test.new.api.ad.xiaomi.com
tracking.miui.com
tw13b093.sandai.net
union.dbba.cn
update.avlyun.sec.miui.com
www.adview.cn
yun.rili.cn
zhwnlapi.etouch.cn
api.comm.miui.com

!小米电视屏蔽广告规则
!https://blog.csdn.net/moshowgame/article/details/79907926
stat.pandora.xiaomi.com
upgrade.mishop.pandora.xiaomi.com
logonext.tv.kuyun.com
config.kuyun.com
api.io.mi.com
mishop.pandora.xiaomi.com
dvb.pandora.xiaomi.com
api.ad.xiaomi.com
de.pandora.xiaomi.com
data.mistat.xiaomi.com
jellyfish.pandora.xiaomi.com
gallery.pandora.xiaomi.com
o2o.api.xiaomi.com
bss.pandora.xiaomi.com
gvod.aiseejapp.atianqi.com
ad.mi.com
ad.xiaomi.com
ad1.xiaomi.com
sdkconfig.ad.xiaomi.com
staging.ai.api.xiaomi.com
b.netcheck.gallery.pandora.xiaomi.com
f1.market.xiaomi.com
f2.market.xiaomi.com
f3.market.xiaomi.com
f4.market.xiaomi.com
f5.market.xiaomi.com
ad.doubleclick.net
v.admaster.com.cn
f1.market.mi-img.com
f2.market.mi-img.com
f3.market.mi-img.com
f4.market.mi-img.com
f5.market.mi-img.com
g.dtv.cn.miaozhan.com
ad.xiaomi.com
ad1.xiaomi.com
new.api.ad.xiaomi.com
api.ad.xiaomi.com
o2o.api.xiaomi.com
```
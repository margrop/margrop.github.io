---
title: 【转】Android实现系统状态栏的隐藏和显示功能
tags: []
published: true
hideInList: false
isTop: false
categories:
  - network
  - Android
date: 2021-07-09 20:41:13
feature:
---
# 问题描述
尤其视频类APP，需要实现切换到横屏后，隐藏系统状态栏，全屏显示，以实现看更大画面的视频。当切换回
竖屏后，又显示状态栏。那么如何实现呢？

# 网上流传着很多种做法
比如
1、在`AndroidManifest.xml`文件中修改`theme`为
```
android:theme="@android:style/Theme.NoTitleBar.Fullscreen"
```

2、在`setContentView`方法前执行如下代码：
```
requestWindowFeature(Window.FEATURE_NO_TITLE) 
 getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,WindowManager.LayoutParams.FLAG_FULLSCREEN);
 ```
3、通过`View`的`setSystemUiVisibility`方法

4、通过如下代码实现状态栏的隐藏和显示：
```
getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN) //隐藏状态栏 
getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN) //显示状态栏
```
在我的项目中是要实现如下需求：在当前`Activity`中，切换到横屏后，不能销毁`Activity`再重新初始化，并且实现隐藏系统状态栏，全屏显示；当切换回竖屏后，又显示状态栏。另外，我不需要隐藏标题栏。

<!-- more -->

因此，方法1、2均不适合我。方法3，我采用过，调用`setSystemUiVisibility`方法，该方法传入的参数可以为：

1. View.SYSTEM_UI_FLAG_VISIBLE：显示状态栏，Activity不全屏显示(恢复到有状态的正常情况)。
2. View.INVISIBLE：隐藏状态栏，同时Activity会伸展全屏显示。
3. View.SYSTEM_UI_FLAG_FULLSCREEN：Activity全屏显示，且状态栏被隐藏覆盖掉。
4. View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN：Activity全屏显示，但状态栏不会被隐藏覆盖，状态栏依然可见，Activity顶端布局部分会被状态遮住。
5. View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION：效果同View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
6. View.SYSTEM_UI_LAYOUT_FLAGS：效果同View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
7. View.SYSTEM_UI_FLAG_HIDE_NAVIGATION：隐藏虚拟按键(导航栏)。有些手机会用虚拟按键来代替物理按键。
8. View.SYSTEM_UI_FLAG_LOW_PROFILE：状态栏显示处于低能显示状态(low profile模式)，状态栏上一些图标显示会被隐藏。

这里我需要传入的是`View.SYSTEM_UI_FLAG_FULLSCREEN`，可是当我传入该参数后，结果是：只是状态栏消失了，但是位置还在。（测试手机：华为荣耀8 系统是基于Android 7.0的EMUI 5.0；三星galaxy s6 系统是Android 6.0）

最后，使用方法4，成功满足需求。 

# 总结

以上所述是小编给大家介绍的Android实现系统状态栏的隐藏和显示功能，希望对大家有所帮助，如果大家有任何疑问请给我留言，小编会及时回复大家的。在此也非常感谢大家对ZaLou.Cn网站的支持！

# 参考
[https://cloud.tencent.com/developer/article/1741895]()
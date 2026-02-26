---
title: SpringBoot DevTools的大坑，没有之一
tags:
  - springboot
  - devtools
  - java
  - hibernate
  - classloader
  - jvm
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-03-03 18:23:39
feature:
---
最近在SpringBoot的项目中新增了不少改动，然后就碰到了一个非常奇怪的问题。

# `Hibernate`数据库查询报错
```java
2021-03-03 17:08:28.016 ERROR 36216 --- [  XNIO-2 task-1] o.h.p.access.spi.SetterMethodImpl        : HHH000123: IllegalArgumentException in class: net.margrop.racentity.entity.Race, setter method of property: raceType
2021-03-03 17:08:28.016 ERROR 36216 --- [  XNIO-2 task-1] o.h.p.access.spi.SetterMethodImpl        : HHH000091: Expected type: net.margrop.raceapi.entity.permanent.RaceType, actual value: net.margrop.raceapi.entity.permanent.RaceType
```
这简直就是奇了怪了
`Expected type`和`actual value`完全是一模一样，可`Hibernate`认为不一样，这可咋整。

<!-- more -->

折腾了1天这个奇葩问题，发现这个只是在我本机才会出现，同样的代码，测试服务器是完全正常的。

好歹有了一点突破口，怀疑是环境的问题，于是又开始统一MySQL版本，统一Java版本，结果完全没效果。

就差快点放弃时，又看到了报错日志的最下端
```java
Caused by: java.lang.IllegalArgumentException: argument type mismatch
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.base/java.lang.reflect.Method.invoke(Method.java:566)
	at org.hibernate.property.access.spi.SetterMethodImpl.set(SetterMethodImpl.java:45)
```

看起来是JDK底层报的错，那么打断点看看

断点调试后，有了一个重大发现！！！

# ClassLoader不一致

两个同样类的`ClassLoader`，一个是`AppClassLoader`，另外一个是`RestartClassLoader`。

最近正好学了`JVM`，关键知识点出现了

# 两个`Class`要相等，需要包名一样，`ClassLoader`也一样

`AppClassLoader`我知道是啥，那`RestartClassLoader`是什么鬼？

在`Google`搜索`RestartClassLoader AppClassLoader`，真相终于出现了，第一页全部都是这些问题。

看来`DevTools`坑了不少人~

# 解决方法
在`pom.xml`中删除`spring-boot-devtools`的依赖。
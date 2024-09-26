---
title: 'Gridea同步github失败最终解决方案'
date: 2021-12-04 11:36:32
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 前言
废话不多说，解决这个问题的核心思路就是跑代理，如果你没有科学上网工具的话，那下面的也就用不着看了，建议你用`coding`吧。

# 重要提示
`Gridea`官方置顶的`issue`版本[`2021.10.23更新，关于检测远程链接成功，但同步错误的案例收集与修复测试包`](https://github.com/getgridea/gridea/issues/890)，该版本的同步功能存在严重的`BUG`，无法正常同步到`Github`。下文基于`Gridea`的正式`0.9.2`版本测试通过。
<!-- more -->

# 开始
众所周知，在天朝一直存在墙这玩意儿，再加上运营商老是没事儿屏蔽一些网站，自然而然有的人的`github`也被屏蔽了，虽然现在很多科学上网工具都提供了全局代理选项，但是我们都知道这玩意儿就扯淡的，所以接下来的我们需要让自己的电脑可以全局代理某一个APP，刚好`proxifier`符合，但是这软件要付费，但是在天朝你懂的。

Mac版本地址：https://www.macwk.com/soft/proxifier
Window版本地址：https://www.hanzify.org/software/13717.html

因为本人是Mac，所以下面截图都是基于`Mac`版本，不过软件的功能都大同小异了。

根据破解教程安装完成后，打开软件开始配置，首先打开`Proxies`菜单，配置如下：
![](https://luoyelusheng.github.io/post-images/1634562555724.png)

在Rules菜单中默认有两个模式，我们点击Add选择新增一条，添加后的结果如下：
![](https://luoyelusheng.github.io/post-images/1634562720051.png)

这里我修改了默认的规则的代理模式为直连模式，毕竟我们只是用这个软件代理`GrideaAPP`，科学上网的功能还是交给我们的科学上网工具来做。

`DNS`和`Advanced`这一栏采用默认配置，结果如下：
![](https://luoyelusheng.github.io/post-images/1634563004134.png)
![](https://luoyelusheng.github.io/post-images/1634563010377.png)
![](https://luoyelusheng.github.io/post-images/1634563015686.png)
![](https://luoyelusheng.github.io/post-images/1634563021171.png)

最后打开我们的`Gridea`软件，点击同步，我们可以在`proxifier`上面看到请求过程：
![](https://luoyelusheng.github.io/post-images/1634563186898.png)

最后的最后当然就是同步成功啦五个字啦！

![](https://luoyelusheng.github.io/post-images/1634563616662.png)

# 参考文章
<https://www.luoyelusheng.com/post/Gridea%E5%90%8C%E6%AD%A5github%E5%A4%B1%E8%B4%A5%E6%9C%80%E7%BB%88%E8%A7%A3%E5%86%B3%E6%96%B9%E6%A1%88/>
<!-- more -->

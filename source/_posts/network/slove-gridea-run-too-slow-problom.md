---
title: 【转】解决Gridea客户端打不开/打开很慢以及同步不了的问题
tags:
  - gridea
published: true
hideInList: false
isTop: false
categories:
  - network
date: 2021-01-15 16:48:39
feature:
---
最近Gridea客户端打开很慢，而且同步也经常失败

在左上角，编辑-->开发者工具-->console，可以看到widget.js加载不出，这是因为cdn.headwayapp.co被墙了，所以需要使用魔法或者把widget.js放到其它CDN

<!-- more -->

如果换到其它CDN的话，需要对客户端修改

```
\Gridea\resources\app\index.html
```

对index.html进行编辑

搜索
```
https://cdn.headwayapp.co/widget.js
```
下面是我的

```
https://cdn.jsdelivr.net/gh/XYZ1024-alt/CDN/widget.js
```

`来源`
<https://xyz1024.top/post/xzimm60l1/>
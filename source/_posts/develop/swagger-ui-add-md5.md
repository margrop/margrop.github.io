---
title: Swagger-UI 增加项目依赖，修改index.html
tags:
  - swagger
  - ui
  - js
  - index
  - md5
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-02-06 09:13:39
feature:
---
# swagger-bundle 打包
首先进入`swagger-ui`目录
```bash
npm install
npm run build
```

# 如何修改
index.html中的url修改为：
```js
url: "/v2/api-docs?group=" + getUrlParam("group"),
```

<!-- more -->


并且增加函数
```js
    function getUrlParam(name) {
        var reg = new RegExp("(^|&)" + name + "=([^&]*)(&|$)"); //构造一个含有目标参数的正则表达式对象
        var r = window.location.search.substr(1).match(reg);  //匹配目标参数
        if (r != null) return unescape(r[2]);
        return ""; //返回参数值
    }
```

![](/post-images/swagger-ui-1.jpg)
![](/post-images/swagger-ui-2.jpg)

---
title: 'Swagger-JS 如何增加MD5校验，和项目依赖'
date: 2021-02-06 09:05:25
tags: [swagger,md5,js]
published: true
hideInList: false
feature: 
isTop: false
---
# swagger-bundle 打包
首先进入`swagger-js`目录
```bash
npm install
npm run build
```

# 如何修改
在`src/execute.js`文件中增加代码：
```js
import md5 from 'md5';
```

<!-- more -->

在`export function buildRequest({`方法类`mergeInQueryOrForm(req)`语句前增加代码：
```js
  //calcSn for server
  var req = request
  console.log(req.body);
  if (req.body) {
    let bodyObj = JSON.parse(req.body);
    bodyObj['header']['token'] = req['headers']['token'];
    bodyObj['header']['snTime'] = (new Date()).valueOf();

    let allData = Object.assign(JSON.parse(JSON.stringify(bodyObj['body'])), {
      token: bodyObj['header']['token'],
      snTime: bodyObj['header']['snTime']
    });
    bodyObj['header']['sn'] = calcSn(allData);
    req.body = JSON.stringify(bodyObj);
    req.headers['X-Sn-Verify'] = md5(req.body);
  }
  console.log(req.body);

  function calcSn(allData) {
    let queryString = "";
    Object.keys(allData)
      .sort()
      .forEach(function (key, i) {
        let value = allData[key];
        queryString += key + "=" + value + "&";
      });
    if (queryString.length > 0) {
      queryString = queryString.substring(0, queryString.length - 1)
    }
    return md5(queryString);
  }
  ```

`package.json`需要增加跨平台编译的支持
![](/post-images/swagger-js-1.jpg)
![](/post-images/swagger-js-2.jpg)
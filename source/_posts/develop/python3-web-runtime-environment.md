---
title: 'Python3的Web环境，含第三方以及自建'
date: 2021-01-24 13:07:30
tags: [python,web,jupter,scipy-notebook,runtime,docker,jupyterlab]
published: true
hideInList: false
feature: 
isTop: false
---
之前因为某件家事，需要使用`Python3`的Web环境，于是收集了一下。
第三方网站的环境使用起来很简单，但缺点也很明显，不能保存上次的`Python`代码。

<!-- more -->

# 第三方网站提供的`Python3`环境

<https://www.w3cschool.cn/tryrun/runcode?lang=python3>
<http://c.runoob.com/compile/9>

于是就自己搭建了一套环境，折腾了半天，最终使用了`Docker`进行搭建，几行代码就搞定了。

`Docker`安装完成后，运行下面的命令，启动容器即可。

# 使用 Docker拉取并运行镜像
```bash
docker pull jupyter/scipy-notebook
docker start --name jupyter-notebook -p 8888:8888 jupyter/scipy-notebook
docker start jupyter-notebook
```
* 记得`docker start jupyter-notebook`第一次启动后，会在容器内的命令行内打印`初始密码`，后面的登录和修改密码都需要使用`初始密码`

# 访问页面
* 在浏览器访问<http://127.0.0.1:8888/>即可




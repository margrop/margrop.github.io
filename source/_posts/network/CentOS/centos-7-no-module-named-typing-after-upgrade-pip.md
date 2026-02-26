---
title: >-
  CentOS 7下，pip install -upgrade pip 导致 pip 无法使用的问题 ImportError: No module named
  typing
tags:
  - python
  - pip
  - centos
published: true
hideInList: false
isTop: false
categories:
  - network
  - CentOS
date: 2021-06-16 11:13:46
feature:
---

# 问题现象
pip安装某第三方 SDK，提示升级 pip，按提示升级 pip 后报错
## 导致报错的 pip 升级命令
```bash
pip install --upgrade pip
```
## pip 错误提示
```bash
Traceback (most recent call last):
  File "/usr/bin/pip", line 9, in <module>
    load_entry_point('pip==21.1.2', 'console_scripts', 'pip')()
  File "/usr/lib/python2.7/site-packages/pkg_resources.py", line 378, in load_entry_point
    return get_distribution(dist).load_entry_point(group, name)
  File "/usr/lib/python2.7/site-packages/pkg_resources.py", line 2566, in load_entry_point
    return ep.load()
  File "/usr/lib/python2.7/site-packages/pkg_resources.py", line 2260, in load
    entry = __import__(self.module_name, globals(),globals(), ['__name__'])
  File "/usr/lib/python2.7/site-packages/pip/__init__.py", line 1, in <module>
    from typing import List, Optional
ImportError: No module named typing
```

<!-- more -->


# 解决办法
1. 卸载当前的 pip
```bash
yum remove python-pip
```

2. 重新从官方网站安装 python2版本的最新的 pip
```bash
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
python get-pip.py
```

# 参考文章
<https://zhoudl.jschrj.com/posts/418.html>
<https://pip.pypa.io/en/stable/installing>
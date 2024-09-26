---
title: 'Python3正则表达式'
date: 2021-02-24 08:38:22
tags: [python]
published: true
hideInList: false
feature: 
isTop: false
---
# re模块
```py
s = r'ABC\-001' # Python的字符串
# 对应的正则表达式字符串不变：
# 'ABC\-001'
```
# 判断正则表达式是否匹配
```py
>>> import re
>>> re.match(r'^\d{3}\-\d{3,8}$', '010-12345')
<_sre.SRE_Match object; span=(0, 9), match='010-12345'>
>>> re.match(r'^\d{3}\-\d{3,8}$', '010 12345')
>>>
```

<!-- more -->


<!-- more -->

# 切分字符串
```py
>>> 'a b   c'.split(' ')
['a', 'b', '', '', 'c']
```
# 分组
```py
>>> m = re.match(r'^(\d{3})-(\d{3,8})$', '010-12345')
>>> m
<_sre.SRE_Match object; span=(0, 9), match='010-12345'>
>>> m.group(0)
'010-12345'
>>> m.group(1)
'010'
>>> m.group(2)
'12345'
```
# 贪婪匹配
```py
>>> re.match(r'^(\d+)(0*)$', '102300').groups()
('102300', '')

>>> re.match(r'^(\d+?)(0*)$', '102300').groups()
('1023', '00')
```
# 编译
```py
>>> import re
# 编译:
>>> re_telephone = re.compile(r'^(\d{3})-(\d{3,8})$')
# 使用：
>>> re_telephone.match('010-12345').groups()
('010', '12345')
>>> re_telephone.match('010-8086').groups()
('010', '8086')
```
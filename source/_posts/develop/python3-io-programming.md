---
title: Python3 IO编程
tags:
  - python
  - io
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-02-26 10:29:31
feature:
---
# 文件读写
## 读文件：read()会一次性读取全部内容
* with 和 try...catch一样，更简介，自动调用close方法
```py
with open('/path/to/file', 'r') as f:
    print(f.read())
```

<!-- more -->

## readlines()：每次读取一行
```py
for line in f.readlines():
    print(line.strip()) # 把末尾的'\n'删掉
```
## 二进制文件
```py
>>> f = open('/Users/michael/test.jpg', 'rb')
>>> f.read()
b'\xff\xd8\xff\xe1\x00\x18Exif\x00\x00...' # 十六进制表示的字节
```
## 字符编码
```py
>>> f = open('/Users/michael/gbk.txt', 'r', encoding='gbk')
>>> f.read()
'测试'
```

## 写文件
```py
>>> f = open('/Users/michael/test.txt', 'w')
>>> f.write('Hello, world!')
>>> f.close()
```

## 操作文件和目录
* 环境变量
```py
>>> os.environ
environ({'VERSIONER_PYTHON_PREFER_32_BIT': 'no', 'TERM_PROGRAM_VERSION': '326', 'LOGNAME': 'michael', 'USER': 'michael', 'PATH': '/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/X11/bin:/usr/local/mysql/bin', ...})

#获取环境变量
>>> os.environ.get('PATH')
'/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/X11/bin:/usr/local/mysql/bin'
>>> os.environ.get('x', 'default')
'default'
```
## 操作文件和目录
* os.path.join()，不要直接使用\或者/
```py
# 查看当前目录的绝对路径:
>>> os.path.abspath('.')
'/Users/michael'
# 在某个目录下创建一个新目录，首先把新目录的完整路径表示出来:
>>> os.path.join('/Users/michael', 'testdir')
'/Users/michael/testdir'
# 然后创建一个目录:
>>> os.mkdir('/Users/michael/testdir')
# 删掉一个目录:
>>> os.rmdir('/Users/michael/testdir')
```
* os.path.split()，不要直接使用\或者/
* os.path.splitext()，不要直接使用\或者/
```py
>>> os.path.split('/Users/michael/testdir/file.txt')
('/Users/michael/testdir', 'file.txt')

>>> os.path.splitext('/path/to/file.txt')
('/path/to/file', '.txt')

```
## 重命名和删除
```py
# 对文件重命名:
>>> os.rename('test.txt', 'test.py')
# 删掉文件:
>>> os.remove('test.py')
```
* 示例
```py
#列出当前目录下的所有目录
>>> [x for x in os.listdir('.') if os.path.isdir(x)]
['.lein', '.local', '.m2', '.npm', '.ssh', '.Trash', '.vim', 'Applications', 'Desktop', ...]

#要列出所有的.py文件
>>> [x for x in os.listdir('.') if os.path.isfile(x) and os.path.splitext(x)[1]=='.py']
['apis.py', 'config.py', 'models.py', 'pymonitor.py', 'test_db.py', 'urls.py', 'wsgiapp.py']
```

# 序列化
## JSON
```py
#Python对象 -> JSON
>>> import json
>>> d = dict(name='Bob', age=20, score=88)
>>> json.dumps(d)
'{"age": 20, "score": 88, "name": "Bob"}'

#JSON -> Python对象
>>> json_str = '{"age": 20, "score": 88, "name": "Bob"}'
>>> json.loads(json_str)
{'age': 20, 'score': 88, 'name': 'Bob'}
```
## JSON进阶，class -> JSON
```py
import json

class Student(object):
    def __init__(self, name, age, score):
        self.name = name
        self.age = age
        self.score = score
        
def student2dict(std):
    return {
        'name': std.name,
        'age': std.age,
        'score': std.score
    }
    
def dict2student(d):
    return Student(d['name'], d['age'], d['score'])
    
>>> s = Student('Bob', 20, 88)

>>> print(json.dumps(s, default=student2dict))
{"age": 20, "name": "Bob", "score": 88}
```py
* JSON进阶，class -> JSON通用方法
``````py
print(json.dumps(s, default=lambda obj: obj.__dict__))
```
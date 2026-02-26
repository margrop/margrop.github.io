---
title: Python3面向对象编程
tags:
  - python
  - oop
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-03-04 22:23:55
feature:
---
# 面向对象编程
```py
class Student(object):

    def __init__(self, name, score):
        self.name = name
        self.score = score

    def print_score(self):
        print('%s: %s' % (self.name, self.score))
```

<!-- more -->

# 访问限制
* Private变量，使用"__"开头命名
```py
class Student(object):

    def __init__(self, name, score):
        self.__name = name
        self.__score = score

    def print_score(self):
        print('%s: %s' % (self.__name, self.__score))
```

#### 继承和多态
* 继承：Dog继承Animal
```py
class Animal(object):
    def run(self):
        print('Animal is running...')
        
class Dog(Animal):
    pass

class Cat(Animal):
    pass
```
* isinstance(a,Class)
```py
>>> isinstance(b, Animal)
True
>>> isinstance(c, Dog)
True
```

# 获取对象信息
* 基本对象类型
```
>>> type(123)
<class 'int'>
>>> type('str')
<class 'str'>
>>> type(None)
<type(None) 'NoneType'>
```
* 函数或类的对象类型
```py
>>> type(abs)
<class 'builtin_function_or_method'>
>>> type(a)
<class '__main__.Animal'>
```
* 类型判断
```py
#基本类型
>>> type(123)==type(456)
True
>>> type(123)==int
True
>>> type('abc')==type('123')
True
>>> type('abc')==str
True
>>> type('abc')==type(123)
False

#函数和类
>>> type(fn)==types.FunctionType
True
>>> type(abs)==types.BuiltinFunctionType
True
>>> type(lambda x: x)==types.LambdaType
True
>>> type((x for x in range(10)))==types.GeneratorType
True
```
* 反射，获得一个对象的所有属性和方法，使用dir()
```py
>>> dir('ABC')
['__add__', '__class__', '__contains__', '__delattr__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattribute__', '__getitem__', '__getnewargs__', '__gt__', '__hash__', '__init__', '__iter__', '__le__', '__len__', '__lt__', '__mod__', '__mul__', '__ne__', '__new__', '__reduce__', '__reduce_ex__', '__repr__', '__rmod__', '__rmul__', '__setattr__', '__sizeof__', '__str__', '__subclasshook__', 'capitalize', 'casefold', 'center', 'count', 'encode', 'endswith', 'expandtabs', 'find', 'format', 'format_map', 'index', 'isalnum', 'isalpha', 'isdecimal', 'isdigit', 'isidentifier', 'islower', 'isnumeric', 'isprintable', 'isspace', 'istitle', 'isupper', 'join', 'ljust', 'lower', 'lstrip', 'maketrans', 'partition', 'replace', 'rfind', 'rindex', 'rjust', 'rpartition', 'rsplit', 'rstrip', 'split', 'splitlines', 'startswith', 'strip', 'swapcase', 'title', 'translate', 'upper', 'zfill']
```
* 反射，getattr()、setattr()以及hasattr()
* 接口，鸭子类型
```py
def readImage(fp):
    if hasattr(fp, 'read'):
        return readData(fp)
    return None
```
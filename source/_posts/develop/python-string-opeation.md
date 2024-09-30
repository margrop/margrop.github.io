---
title: 'Python3常用字符串操作'
date: 2021-02-14 22:33:22
tags: [python,string,print]
published: true
hideInList: false
feature: 
isTop: false
---

#  python print
* 不换行（在后面加上,end=''）
```
print(string,end='') 
```

<!-- more -->


# python split()
* 通过指定分隔符对字符串进行切片，如果参数num 有指定值，则仅分隔 num 个子字符串
* split()方法语法：
```
str.split(str="", num=string.count(str)).
```

## 参数
* str -- 分隔符，默认为空格。
* num -- 分割次数。
## 返回值
返回分割后的字符串列表。

* 实例：以下实例展示了split()函数的使用方法：
```py
#!/usr/bin/python
str = "Line1-abcdef \nLine2-abc \nLine4-abcd";
print(str.split(' '))
print(str.split(' ',1);
```
* 以上实例输出结果如下：
```py
['Line1-abcdef', 'Line2-abc', 'Line4-abcd']
['Line1-abcdef', '\nLine2-abc \nLine4-abcd']
```

```py
table = html[html.find('<table class="fzTab nbt">') : html.find('</table>')]
#print (table)
#<tr onmouseout="this.style.background=''" onmouseover="this.style.background='#fff7d8'">
#<tr \r\n\t\t onmouseout=
tmp = table.split('<tr \r\n\t\t onmouseout=',1)
#print(tmp)
#print(len(tmp))
trs = tmp[1]
tr = trs[: trs.find('</tr>')]
#print(tr)
number = tr.split('<td >')[1].split('</td>')[0]
print(number + '期开奖号码：',end='')
redtmp = tr.split('<td class="redColor sz12" >')
reds = redtmp[1:len(redtmp)-1]#去掉第一个和最后一个没用的元素
#print(reds)
for redstr in reds:
print(redstr.split('</td>')[0] + ",",end='')
print('篮球：',end='')
blue = tr.split('<td class="blueColor sz12" >')[1].split('</td>')[0]
print(blue)
```

# Python 字符串操作（string替换、删除、截取、复制、连接、比较、查找、包含、大小写转换、分割等）
* 去空格及特殊符号
```py
s.strip().lstrip().rstrip(',')
```
* 复制字符串
```py
#strcpy(sStr1,sStr2)
sStr1 = 'strcpy'
sStr2 = sStr1
sStr1 = 'strcpy2'
print sStr2
```
* 连接字符串
```py
#strcat(sStr1,sStr2)
sStr1 = 'strcat'
sStr2 = 'append'
sStr1 += sStr2
print sStr1
```
* 查找字符
```py
#strchr(sStr1,sStr2)
# < 0 为未找到
sStr1 = 'strchr'
sStr2 = 's'
nPos = sStr1.index(sStr2)
print nPos
```
* 比较字符串
```py
#strcmp(sStr1,sStr2)
sStr1 = 'strchr'
sStr2 = 'strch'
print cmp(sStr1,sStr2)
```
* 扫描字符串是否包含指定的字符
```py
#strspn(sStr1,sStr2)
sStr1 = '12345678'
sStr2 = '456'
#sStr1 and chars both in sStr1 and sStr2
print len(sStr1 and sStr2)
```
* 字符串长度
```py
#strlen(sStr1)
sStr1 = 'strlen'
print len(sStr1)
```
* 将字符串中的大小写转换
```py
#strlwr(sStr1)
sStr1 = 'JCstrlwr'
sStr1 = sStr1.upper()
#sStr1 = sStr1.lower()
print sStr1
```
* 追加指定长度的字符串
```py
#strncat(sStr1,sStr2,n)
sStr1 = '12345'
sStr2 = 'abcdef'
n = 3
sStr1 += sStr2[0:n]
print sStr1
```
* 字符串指定长度比较
```py
#strncmp(sStr1,sStr2,n)
sStr1 = '12345'
sStr2 = '123bc'
n = 3
print cmp(sStr1[0:n],sStr2[0:n])
```
* 复制指定长度的字符
```
#strncpy(sStr1,sStr2,n)
sStr1 = ''
sStr2 = '12345'
n = 3
sStr1 = sStr2[0:n]
print sStr1
```
* 将字符串前n个字符替换为指定的字符
```py
#strnset(sStr1,ch,n)
sStr1 = '12345'
ch = 'r'
n = 3
sStr1 = n * ch + sStr1[3:]
print sStr1
```
* 扫描字符串
```py
#strpbrk(sStr1,sStr2)
sStr1 = 'cekjgdklab'
sStr2 = 'gka'
nPos = -1
for c in sStr1:
if c in sStr2:
nPos = sStr1.index(c)
break
print nPos
```
* 翻转字符串
```py
#strrev(sStr1)
sStr1 = 'abcdefg'
sStr1 = sStr1[::-1]
print sStr1
```
* 查找字符串
```py
#strstr(sStr1,sStr2)
sStr1 = 'abcdefg'
sStr2 = 'cde'
print sStr1.find(sStr2)
```
* 分割字符串
```py
#strtok(sStr1,sStr2)
sStr1 = 'ab,cde,fgh,ijk'
sStr2 = ','
sStr1 = sStr1[sStr1.find(sStr2) + 1:]
print sStr1
#或者
s = 'ab,cde,fgh,ijk'
print(s.split(','))
```
* 连接字符串
```py
delimiter = ','
mylist = ['Brazil', 'Russia', 'India', 'China']
print delimiter.join(mylist)
PHP 中 addslashes 的实现

def addslashes(s):
d = {'"':'\\"', "'":"\\'", "\0":"\\\0", "\\":"\\\\"}
return ''.join(d.get(c, c) for c in s)

s = "John 'Johny' Doe (a.k.a. \"Super Joe\")\\\0"
print s
print addslashes(s)
```
* 只显示字母与数字
```py
def OnlyCharNum(s,oth=''):
s2 = s.lower();
fomart = 'abcdefghijklmnopqrstuvwxyz0123456789'
for c in s2:
if not c in fomart:
s = s.replace(c,'');
return s;

print(OnlyStr("a000 aa-b"))
```

* 截取字符串
```py
str = '0123456789'
print str[0:3] #截取第一位到第三位的字符
print str[:] #截取字符串的全部字符
print str[6:] #截取第七个字符到结尾
print str[:-3] #截取从头开始到倒数第三个字符之前
print str[2] #截取第三个字符
print str[-1] #截取倒数第一个字符
print str[::-1] #创造一个与原字符串顺序相反的字符串
print str[-3:-1] #截取倒数第三位与倒数第一位之前的字符
print str[-3:] #截取倒数第三位到结尾
print(str[:-5:-3]) #逆序截取，输出96
print(str[:-4:-2])#逆序截取，输出97
print(str[:-6:-2])#逆序截取，输出975
```

参考文章
<http://www.cnblogs.com/zdz8207/p/python_learn_note_15.html>
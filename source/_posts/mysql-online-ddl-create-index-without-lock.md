---
title: 'Mysql online DDL 线上无锁添加索引'
date: 2023-04-02 08:51:17
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 步骤

只能通过ALTER TABLE不能create index
```
ALTER TABLE tbl_name ADD INDEX (column), ALGORITHM=INPLACE, LOCK=NONE;
```

<!-- more -->

## 参数说明：

`ALGORITHM=INPLACE`
更优秀的解决方案，在当前表加索引，步骤：
1.创建索引(二级索引)数据字典
2.加共享表锁，禁止DML，允许查询
3.读取聚簇索引，构造新的索引项，排序并插
入新索引
4.等待打开当前表的所有只读事务提交
5.创建索引结束
 
`ALGORITHM=COPY`
通过临时表创建索引，需要多一倍存储，还有更多的IO，步骤：
1.新建带索引（主键索引）的临时表
2.锁原表，禁止DML，允许查询
3.将原表数据拷贝到临时表
4.禁止读写,进行rename，升级字典锁
5.完成创建索引操作
 
`LOCK=DEFAULT`：默认方式，MySQL自行判断使用哪种LOCK模式，尽量不锁表
`LOCK=NONE`：无锁：允许Online DDL期间进行并发读写操作。如果Online DDL操
作不支持对表的继续写入，则DDL操作失败，对表修改无效
`LOCK=SHARED`：共享锁：Online DDL操作期间堵塞写入，不影响读取
`LOCK=EXCLUSIVE`：排它锁：Online DDL操作期间不允许对锁表进行任何操作 

# 来源
<https://dev.mysql.com/doc/refman/8.0/en/create-index.html>
<https://dev.mysql.com/doc/refman/8.0/en/innodb-online-ddl-operations.html#online-ddl-index-syntax-notes>
<https://stackoverflow.com/questions/4244685/create-an-index-on-a-huge-mysql-production-table-without-table-locking>
<https://www.jianshu.com/p/81d7d7ed6d86>
---
title: 解决 PostgreSQL 10 升级至 11，Permissions should be u=rwx (0700)问题
tags: []
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-08-23 16:45:41
feature:
---
# 问题描述

今天打算把 Gitlab 从 11 版本升级到 12 版本，按默认的步骤试了很多次都没成功。

真不甘心，找了半天，终于在 PostgreSQL 日志里面，发现了错误
```bash
command: "/usr/lib/postgresql/10/bin/pg_ctl" -w -l "pg_upgrade_server.log" -D "/var/lib/postgresql/10/main" -o "-p 50432 -c autovacuum=off -c autovacuum_freeze_max_age=2000000000 -c config_file=/var/lib/postgresql/10/main/postgresql.conf --hba_file=/var/lib/postgresql/10/main/pg_hba.conf --ident_file=/var/lib/postgresql/10/main/pg_ident.conf -c listen_addresses='' -c unix_socket_permissions=0700" start >> "pg_upgrade_server.log" 2>&1
pg_ctl: another server might be running; trying to start server anyway
waiting for server to start....2021-08-23 07:11:37.208 UTC [1385] FATAL:  data directory "/var/lib/postgresql/10/main" has group or world access
2021-08-23 07:11:37.208 UTC [1385] DETAIL:  Permissions should be u=rwx (0700).
 stopped waiting
pg_ctl: could not start server
Examine the log output.
```

关键的两行日志如下：
```
2021-08-23 07:11:37.208 UTC [1385] FATAL:  data directory "/var/lib/postgresql/10/main" has group or world access
2021-08-23 07:11:37.208 UTC [1385] DETAIL:  Permissions should be u=rwx (0700).
 stopped waiting
```

<!-- more -->

# 搜索问题
使用 Google 搜索『data directory has group or world access』

第一条结果就是解决办法，[Postgres exits with "Permissions should be u=rwx (0700)" #45](https://github.com/ClusterHQ/dvol/issues/45)

# 解决问题
1. 使用 `root` 账号执行命令`sudo chmod 700 -R /var/lib/postgresql/data`
2. 重新执行 `pg_ctl` 的升级命令
```bash
 "/usr/lib/postgresql/10/bin/pg_ctl" -w -l "pg_upgrade_server.log" -D "/var/lib/postgresql/10/main" -o "-p 50432 -c autovacuum=off -c autovacuum_freeze_max_age=2000000000 -c config_file=/var/lib/postgresql/10/main/postgresql.conf --hba_file=/var/lib/postgresql/10/main/pg_hba.conf --ident_file=/var/lib/postgresql/10/main/pg_ident.conf -c listen_addresses='' -c unix_socket_permissions=0700" start >> "pg_upgrade_server.log" 2>&1
```

# 参考
<https://github.com/ClusterHQ/dvol/issues/45>








---
title: Maven单独的settings.xml配置文件，国内阿里云镜像
tags: []
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-12-04 14:06:23
feature:
---
```
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                          https://maven.apache.org/xsd/settings-1.0.0.xsd">

      <mirrors>
        <mirror>  
            <id>alimaven</id>  
            <name>aliyun maven</name>  
            <url>https://maven.aliyun.com/repository/public</url>
            <mirrorOf>central</mirrorOf>          
        </mirror>  
      </mirrors>
</settings>
```

<!-- more -->

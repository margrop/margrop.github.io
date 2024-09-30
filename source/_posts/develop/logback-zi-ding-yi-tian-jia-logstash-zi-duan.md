---
title: 'logback 自定义添加 logstash 字段'
date: 2023-04-02 08:57:41
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 步骤

## 如果想在输出的JSON中，加上自定义字段，需要配置arguments参数
```xml
<encoder class="net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder">
        <providers>
            <pattern>
                <pattern>
                    {
                    "timestamp": "%date{\"yyyy-MM-dd HH:mm:ss\"}",
                    "log_level": "%level",
                    "class_name": "%class",
                    "thread": "%thread",
                    "message": "%message",
                    "stack_trace": "%exception{5}"
                    }
                </pattern>
            </pattern>
            <arguments/>
        </providers>
    </encoder>
```

<!-- more -->

## Markers提供的标记
```java
import static net.logstash.logback.marker.Markers.*

 /*
 * Add "name":"value" to the JSON output.
 */
logger.info(append("name", "value"), "log message");

/*
 * Add "name1":"value1","name2":"value2" to the JSON output by using multiple markers.
 */
logger.info(append("name1", "value1").and(append("name2", "value2")), "log message");
```

# 来源
<https://bloodhunter.github.io/2019/02/01/logback-pei-zhi/>
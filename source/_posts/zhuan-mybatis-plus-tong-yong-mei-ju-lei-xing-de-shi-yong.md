---
title: '【转】Mybatis-Plus 通用枚举类型的使用'
date: 2022-02-02 20:20:58
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
有些字段，例如性别、婚姻状况、等标志性字段，在数据库中存放的形式往往是数字，0 或者 1，这样做的好处是存取的效率高节省空间，但是前端的在展示的时候不能直接展示，需要进行一个判断，但是判断逻辑放在前端不妥，所以后端应该提前将值转换好返回该前端。

<!-- more -->

在 `Mybatis-Plus` 中我们可以使用`枚举类型`来完成这一操作，他能自动将数据库里的字段映射成我们需要的字段，例如性别，新建枚举类如下：
```java
@Getter
public enum GenderType {
    WOMEN(0, "女"),
    MAN(1, "男");

    @EnumValue
    private Integer key;

    @JsonValue
    private String name;

    GenderType(Integer key, String name) {
        this.key = key;
        this.name = name;
    }
    
    @Override
    public String toString() {
        return this.name;
    }
}
```
其中最关键的是 `@EnumValue` 注解，他是标注数据库里存的字段，这里数据库里存的是 `key`，`@JsonValue` 标注的是要展示的字段，这里我们想展示给前端的是 `name` 字段，同时要重写 `toString` 方法为我们想要的，因为系统会自动调用该方法作为前端的展示值，这里想要展示 `name`，所以直接返回它就行了。

关键点：

* `@EnumValue`：标注哪一个字段是数据库里的字段；
* `@JsonValue`：标注要开启自定义序列化返回值；
* `toString`：具体的返回值；

同时我们需要在与数据库关联的实体类中修改类型，将性别字段改为枚举类型：
```java
@Data
@TableName("table")
public class ZhbfDb extends SymqBaseEntity {
    /**
     * 姓名
     */
    private String name;
    /**
     * 性别
     */
    private GenderType gender;
}
```
在配置文件中配置扫描注解类型：

#mybatis-plus 配置
```yaml
mybatis-plus:
  type-enums-package: com.demo.test.enums
```
这个时候再去查询，返回的结果就直接是我们在枚举类型中定义的 `name` 值了。

原文链接：https://blog.csdn.net/weixin_43941364/article/details/119821877
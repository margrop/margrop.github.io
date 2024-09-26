---
title: '如何使用通用的Hibernate类型映射JSON对象'
date: 2021-01-29 16:06:09
tags: [java,jpa,hibernate,json,jsonb,maven,MySQL,PostgreSQL]
published: true
hideInList: false
feature: 
isTop: false
---
[Hibernate Types]: http://www.google.com/ "Hibernate Types"

# 介绍
在本文中，我们将看到如何使用[Hibernate Types][]开源项目将JSON列映射到JPA实体属性。

虽然您可以创建自己的自定义Hibernate类型，但可以在Oracle，SQL Server，PostgreSQL或MySQL上映射JSON列类型，但是由于[Hibernate Types][]项目已经提供了此功能，因此您无需实现自己的Hibernate Type 。

<!-- more -->

# 领域模型
假设我们具有以下域模型：
![JsonType域模型](https://vladmihalcea.com/wp-content/uploads/2016/06/jsontypedomainmodel.png)

Location和Ticket是JSON Object(s)，而Event和Participant是JPA实体。我们的目标是提供一种Type适用于任何类型的JSON JavaObject以及支持JSON列的任何关系数据库的Hibernate JSON 。

# Maven依赖
您需要做的第一件事是在项目pom.xml配置文件中设置以下Maven依赖项：

```xml
<dependency>
    <groupId>com.vladmihalcea</groupId>
    <artifactId>hibernate-types-52</artifactId>
    <version>${hibernate-types.version}</version>
</dependency>
```
如果您使用的是Hibernate的旧版本，请查看[hibernate-types`GitHub存储库`](https://github.com/vladmihalcea/hibernate-types)，以获取有关当前Hibernate版本的匹配依赖项的更多信息。

# 声明Hibernate Types
要使用JSON Hibernate Types，我们必须使用@TypeDef注释声明它们：

```java
@TypeDefs({
    @TypeDef(name = "json", typeClass = JsonStringType.class),
    @TypeDef(name = "jsonb", typeClass = JsonBinaryType.class)
})
@MappedSuperclass
public class BaseEntity {
    //Code omitted for brevity
}
```
> TypeDef批注可以应用于基本实体类，也可以应用于与当前实体包关联的package-info.java文件。

# MySQL
MySQL 5.7增加了对JSON类型的支持，在JDBC级别上，需要将其实现为String。因此，我们将使用JsonStringType。

实体映射如下所示：

```java
@Entity(name = "Event")
@Table(name = "event")
public class Event extends BaseEntity {
 
    @Type(type = "json")
    @Column(columnDefinition = "json")
    private Location location;
 
    public Location getLocation() {
        return location;
    }
 
    public void setLocation(Location location) {
        this.location = location;
    }
}
 
@Entity(name = "Participant")
@Table(name = "participant")
public class Participant extends BaseEntity {
 
    @Type(type = "json")
    @Column(columnDefinition = "json")
    private Ticket ticket;
 
    @ManyToOne
    private Event event;
 
    public Ticket getTicket() {
        return ticket;
    }
 
    public void setTicket(Ticket ticket) {
        this.ticket = ticket;
    }
 
    public Event getEvent() {
        return event;
    }
 
    public void setEvent(Event event) {
        this.event = event;
    }
}
```
插入以下实体时：

```java
final AtomicReference<Event> eventHolder = new AtomicReference<>();
final AtomicReference<Participant> participantHolder = new AtomicReference<>();
 
doInJPA(entityManager -> {
    Event nullEvent = new Event();
    nullEvent.setId(0L);
    entityManager.persist(nullEvent);
 
    Location location = new Location();
    location.setCountry("Romania");
    location.setCity("Cluj-Napoca");
 
    Event event = new Event();
    event.setId(1L);
    event.setLocation(location);
    entityManager.persist(event);
 
    Ticket ticket = new Ticket();
    ticket.setPrice(12.34d);
    ticket.setRegistrationCode("ABC123");
 
    Participant participant = new Participant();
    participant.setId(1L);
    participant.setTicket(ticket);
    participant.setEvent(event);
 
    entityManager.persist(participant);
 
    eventHolder.set(event);
    participantHolder.set(participant);
});
```
Hibernate生成以下语句：

```java
INSERT INTO event (location, id)
VALUES (NULL(OTHER), 0)
 
INSERT INTO event (location, id)
VALUES ('{"country":"Romania","city":"Cluj-Napoca"}', 1)
 
INSERT INTO participant (event_id, ticket, id)
VALUES (1, {"registrationCode":"ABC123","price":12.34}, 1)
```
JSONObject(s)已正确实现在其关联的数据库列中。

不仅JSONObject(s)已从其数据库表示形式正确转换：
```java
Event event = entityManager.find(Event.class, eventHolder.get().getId());
 
assertEquals("Cluj-Napoca", event.getLocation().getCity());
 
Participant participant = entityManager.find(
    Participant.class, participantHolder.get().getId());
assertEquals("ABC123", participant.getTicket().getRegistrationCode());
```
但是我们甚至可以发出基于JSON的本地SQL查询：

```java
List<String> participants = entityManager.createNativeQuery(
    "SELECT p.ticket -> \"$.registrationCode\" " +
    "FROM participant p " +
    "WHERE JSON_EXTRACT(p.ticket, \"$.price\") > 1 ")
.getResultList();
```
Object(s)可以修改JSON ：

```java
event.getLocation().setCity("Constanța");
entityManager.flush();
```
Hibernate生成正确的UPDATE语句：

```java
UPDATE event
SET location = '{"country":"Romania","city":"Constanța"}'
WHERE id = 1
```

# PostgreSQL
从9.2版开始，PostgreSQL就一直支持JSON类型。有两种类型可以使用：
* json
* jsonb
两种PostgreSQL JSON类型都需要使用二进制数据格式来实现，因此我们需要使用JsonBinaryType这次。

#  PostgreSQL JSON列类型
对于JSON列类型，Object(s)必须如下更改两个JSON映射：

```java
@Type(type = "jsonb")
@Column(columnDefinition = "json")
private Location location;
 
@Type(type = "jsonb")
@Column(columnDefinition = "json")
private Ticket ticket;
```
插入和实体更新都一样，甚至可以JSON按以下方式查询该列：

```java
List<String> participants = entityManager.createNativeQuery(
    "SELECT p.ticket ->>'registrationCode' " +
    "FROM participant p " +
    "WHERE p.ticket ->> 'price' > '10'")
.getResultList();
```
#  PostgreSQL JSONB列类型
对于JSONB列类型，我们只需要更改columnDefinition属性，因为json和jsonbPostgreSQL列类型都由来处理JsonBinaryType：

```java
@Type(type = "jsonb")
@Column(columnDefinition = "jsonb")
private Location location;
 
@Type(type = "jsonb")
@Column(columnDefinition = "jsonb")
private Ticket ticket;
```
插入和JSONObject更新的工作方式相同，而JSONB列类型提供了更高级的查询功能：

```java
List<String> participants = entityManager.createNativeQuery(
    "SELECT jsonb_pretty(p.ticket) " +
    "FROM participant p " +
    "WHERE p.ticket ->> 'price' > '10'")
.getResultList();
```

参考
[How to map JSON objects using generic Hibernate Types](https://vladmihalcea.com/how-to-map-json-objects-using-generic-hibernate-types/)

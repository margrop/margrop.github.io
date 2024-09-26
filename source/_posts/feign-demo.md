---
title: 'feign 使用示例：@Body注解，http请求体'
date: 2021-03-05 18:25:23
tags: [javascript,feign,openfeign,demo,json]
published: true
hideInList: false
feature: 
isTop: false
---
出现接口使用http请求体来传递参数的情况，所以研究了一下feign，发现@Body注解大致可以实现。
虽然说是使用请求体来传递参数，但实质上请求体还是放了json格式的数据。当然，如果不想只局限于json格式，可以将其设置为通用的格式，详见文末。

<!-- more -->

* maven依赖
```xml
        <dependency><!-- 更容易的调用第三方接口 -->
            <groupId>io.github.openfeign</groupId>
            <artifactId>feign-slf4j</artifactId>
            <version>11.0</version>
        </dependency>
        <dependency><!-- 更容易的调用第三方接口 -->
            <groupId>io.github.openfeign</groupId>
            <artifactId>feign-okhttp</artifactId>
            <version>11.0</version>
        </dependency>
        <dependency><!-- 更容易的调用第三方接口 -->
            <groupId>io.github.openfeign</groupId>
            <artifactId>feign-gson</artifactId>
            <version>11.0</version>
        </dependency>
```
OpenFeign 客户端初始化代码
```java
        Feign.builder()
                .client(new OkHttpClient())
                .encoder(new GsonEncoder())
                .decoder(new GsonDecoder())
                .logger(new Slf4jLogger())
                .logLevel(feign.Logger.Level.FULL)
                .target(ApplyV3Api.class, server);
```
先来一个简单的例子

# 使用预定义模板方式的请求体
使用@Body注解，定义模板。客户端通过feign向服务端发送请求。
客户端的代码：
```java
interface FeignClientAPI {
	@RequestLine("POST /jsonBody")
	@Headers("Content-Type: application/json")
	//因为'{}'在模板中有特殊作用（占位符），所以json的首尾中括号需要转义。'{'=>'%7B'，'}'=>'%7D'
	@Body("%7B\"id\": \"{id}\", \"name\": \"{name}\"%7D") 
	String jsonBody(@Param("id") String id, @Param("name") String name);
}
```java
//客户端调用
feignClient.jsonBody("xxId", "xxName");
```
服务端的代码：
```java
@RequestMapping("/jsonBody")
@ResponseBody
public Object jsonBody(@RequestBody JSONObject body){
	System.out.println(body);
	return "success";
}
```
看了上面一个例子，你会感觉很鸡肋，这json还要预定义，这怎么玩嘛。

# 使用参数模板方式的请求体
## 使用String作为方法参数
上面例子我们知道，@Body注解支持"{}"形式的占位符，会将方法中的参数填充到模板中，嘿嘿嘿，我们直接将参数当做模板如何，见下
客户端的代码：
```java
interface FeignClientAPI {
	@RequestLine("POST /jsonBody")
	@Headers("Content-Type: application/json")
	@Body("{body}")
	String jsonBody(@Param("body") String body);
}
```
发现区别了吗，我们直接给@Body注解定义了一个"{body}"。
那么客户端调用时，相应的传参就不是一个个字段了，而是一整个json。
```java
//客户端调用
JSONObject body = new JSONObject();
body.put("id", "xxId");
body.put("name", "xxName");
feignClient.jsonBody(body.toJSONString());
```
服务端的代码不需要变化。

# 使用Bean作为方法参数（toString)
feign方法参数使用String类型总感觉诸多不便，通过翻阅代码（详见feign.template.Expressions.SimpleExpression#expand(java.lang.Object, boolean)），发现可以直接使用对象参数，不过使用的对象需要重写toString方法，因为内部实现是调用对象的toString转成字符串处理。

客户端的代码：
```java
interface FeignClientAPI {
	@RequestLine("POST /jsonBody")
	@Headers("Content-Type: application/json")
	@Body("{body}")
	String jsonBody(@Param("body") InitBean bean);
}

@lombok.Data
public class InitBean {
	private String id;
	private String name;
	
	public String toString(){
		return com.alibaba.fastjson.JSON.toJSONString(this);
	}
}```
客户端调用时，直接传Bean。
```java
//客户端调用
InitBean bean = new InitBean ().setId("xxId").setName("xxName");
feignClient.jsonBody(bean);
```
服务端的代码不需要变化。

# 再进一步，将请求体与其他形式的参数配合使用
下面有三段扩展示例，每个示例包括客户端代码和服务端代码，客户端调用的代码你懂的吧，省略了。
```java
/***************** 扩展一：请求体 + Restful风格URL ******************/
//客户端代码
	@RequestLine("POST /jsonBody/{path}")
	@Headers("Content-Type: application/json")
	@Body("{body}")
	String jsonBodyAndPath(@Param("body") String body, @Param(value="path") String path);
//服务端代码
	@RequestMapping("/jsonBody/{path}")
	@ResponseBody
	public Object jsonBodyAndPath(@RequestBody JSONObject body, @PathVariable String path){
		System.out.println(body);
		System.out.println(path);
		return "success";
	}
```
```java
/***************** 扩展二：请求体 + 请求参数 ******************/
//客户端代码
	@RequestLine("POST /jsonBodyWithParam")
	@Headers("Content-Type: application/json")
	@Body("{body}")
	String jsonBodyWithParam(@Param("body") String body, @QueryMap Map map);
	
//服务端代码
	@RequestMapping("/jsonBodyWithParam")
	@ResponseBody
	public Object jsonBodyWithParam(@RequestBody JSONObject body, @RequestParam String param){
		System.out.println(body);
		System.out.println(param);
		return "success";
	}
```
```java
/***************** 扩展三：请求体 + Restful风格URL + 请求参数 ******************/
//客户端代码
	@RequestLine("POST /jsonBodyAndPathWithParam/{path}")
	@Headers("Content-Type: application/json")
	@Body("{body}")
	String jsonBodyAndPathWithParam(@Param("body") String body, @Param(value="path") String path, @QueryMap Map map);
	
//服务端代码
	@RequestMapping("/jsonBodyAndPathWithParam/{path}")
	@ResponseBody
	public Object jsonBodyAndPathWithParam(@RequestBody JSONObject body, @PathVariable String path, @RequestParam String param){
		System.out.println(body);
		System.out.println(path);
		System.out.println(param);
		return "success";
	}
```
希望上面代码的排版不会把你搞蒙（写一起会比较紧凑吧/捂脸）

# 扩展一下，非json格式的请求体
上面的示例都是以请求体为json格式数据为大前提，那么，遇到不是json格式的请求体，比如是xml格式的呢？？
这里我是直接将客户端的代码的请求头改为了 @Headers(“Content-Type: text/plain;”)，表示这个请求体为普通文本类型。如下
```java
@RequestLine("POST /stringBody")
//将请求内容设置为简单文本类型
@Headers("Content-Type: text/plain;")
@Body("{body}")
String stringBody(@Param("body") String body);
```
相应的，服务端代码使用String做接收参数，来接收请求体的内容。服务端接收到string后，转化为相应的类型
```java
@RequestMapping("/stringBody")
@ResponseBody
public Object stringBody(@RequestBody String body) throws DocumentException {
	System.out.println(body);
	//string 转 json
	JSONObject jsonObject = com.alibaba.fastjson.JSONObject.parseObject(body);
	//或者 string 转 xml
	Document document = org.dom4j.DocumentHelper.parseText(body);
	//或其他...
	return "success";
}
```
基本是上述思路，还没有发掘其他方式实现，如果更好的实现方式，感谢分享，一起探讨。

# 参考文章
<https://blog.csdn.net/qq_31772441/article/details/100176834>
<https://blog.csdn.net/sinat_36553913/article/details/104469418>
<https://blog.csdn.net/sinat_36553913/article/details/104527072>
<https://www.jianshu.com/p/0834508b7a6d>
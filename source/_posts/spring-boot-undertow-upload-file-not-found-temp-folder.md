---
title: 'Spring Boot + Undertow上传文件找不到临时目录'
date: 2021-03-27 11:17:26
cover: /images/banner/1011_20240927_021456.webp
coverWidth: 1280
coverHeight: 720
tags: [java,springboot,undertow]
published: true
hideInList: false
feature: 
isTop: false
---
# 问题出现

前2天，公司的 SpringBoot 项目突然出现了，无法上传 Excel 文件的问题。

经过查看 Java 日志，发现出现了大量的异常：`java.nio.file.NoSuchFileException: /tmp/undertow.12020.9432679758080410942/undertow17157208698492118168upload`

<!-- more -->

详细异常信息如下：
```java
org.springframework.web.multipart.MultipartException: Failed to parse multipart servlet request; nested exception is java.lang.RuntimeException: java.nio.file.NoSuchFileException: /tmp/undertow.12020.9432679758080410942/undertow17157208698492118168upload
	at org.springframework.web.multipart.support.StandardMultipartHttpServletRequest.handleParseFailure(StandardMultipartHttpServletRequest.java:124)
	at org.springframework.web.multipart.support.StandardMultipartHttpServletRequest.parseRequest(StandardMultipartHttpServletRequest.java:115)
	at org.springframework.web.multipart.support.StandardMultipartHttpServletRequest.<init>(StandardMultipartHttpServletRequest.java:88)
	at org.springframework.web.multipart.support.StandardServletMultipartResolver.resolveMultipart(StandardServletMultipartResolver.java:87)
	at org.springframework.web.servlet.DispatcherServlet.checkMultipart(DispatcherServlet.java:1199)
	at org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:1033)
	at org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:961)
	at org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:1006)
	at org.springframework.web.servlet.FrameworkServlet.doPost(FrameworkServlet.java:909)
	at javax.servlet.http.HttpServlet.service(HttpServlet.java:517)
	at org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:883)
	at javax.servlet.http.HttpServlet.service(HttpServlet.java:584)
	at io.undertow.servlet.handlers.ServletHandler.handleRequest(ServletHandler.java:74)
	at io.undertow.servlet.handlers.FilterHandler$FilterChainImpl.doFilter(FilterHandler.java:129)
	at me.ymq.starterapi.filter.ReplaceStreamFilter.doFilter(ReplaceStreamFilter.java:33)
	at io.undertow.servlet.core.ManagedFilter.doFilter(ManagedFilter.java:61)
	at io.undertow.servlet.handlers.FilterHandler$FilterChainImpl.doFilter(FilterHandler.java:131)
	at org.springframework.web.filter.RequestContextFilter.doFilterInternal(RequestContextFilter.java:100)
	at org.springframework.web.filter.OncePerRequestFilter.doFilter(OncePerRequestFilter.java:119)
	at io.undertow.servlet.core.ManagedFilter.doFilter(ManagedFilter.java:61)
	at io.undertow.servlet.handlers.FilterHandler$FilterChainImpl.doFilter(FilterHandler.java:131)
	at org.springframework.web.filter.FormContentFilter.doFilterInternal(FormContentFilter.java:93)
	at org.springframework.web.filter.OncePerRequestFilter.doFilter(OncePerRequestFilter.java:119)
	at io.undertow.servlet.core.ManagedFilter.doFilter(ManagedFilter.java:61)
	at io.undertow.servlet.handlers.FilterHandler$FilterChainImpl.doFilter(FilterHandler.java:131)
	at org.springframework.boot.actuate.metrics.web.servlet.WebMvcMetricsFilter.doFilterInternal(WebMvcMetricsFilter.java:93)
	at org.springframework.web.filter.OncePerRequestFilter.doFilter(OncePerRequestFilter.java:119)
	at io.undertow.servlet.core.ManagedFilter.doFilter(ManagedFilter.java:61)
	at io.undertow.servlet.handlers.FilterHandler$FilterChainImpl.doFilter(FilterHandler.java:131)
	at org.springframework.web.filter.CharacterEncodingFilter.doFilterInternal(CharacterEncodingFilter.java:201)
	at org.springframework.web.filter.OncePerRequestFilter.doFilter(OncePerRequestFilter.java:119)
	at io.undertow.servlet.core.ManagedFilter.doFilter(ManagedFilter.java:61)
	at io.undertow.servlet.handlers.FilterHandler$FilterChainImpl.doFilter(FilterHandler.java:131)
	at io.undertow.servlet.handlers.FilterHandler.handleRequest(FilterHandler.java:84)
	at io.undertow.servlet.handlers.security.ServletSecurityRoleHandler.handleRequest(ServletSecurityRoleHandler.java:62)
	at io.undertow.servlet.handlers.ServletChain$1.handleRequest(ServletChain.java:68)
	at io.undertow.servlet.handlers.ServletDispatchingHandler.handleRequest(ServletDispatchingHandler.java:36)
	at io.undertow.servlet.handlers.RedirectDirHandler.handleRequest(RedirectDirHandler.java:68)
	at io.undertow.servlet.handlers.security.SSLInformationAssociationHandler.handleRequest(SSLInformationAssociationHandler.java:132)
	at io.undertow.servlet.handlers.security.ServletAuthenticationCallHandler.handleRequest(ServletAuthenticationCallHandler.java:57)
	at io.undertow.server.handlers.PredicateHandler.handleRequest(PredicateHandler.java:43)
	at io.undertow.security.handlers.AbstractConfidentialityHandler.handleRequest(AbstractConfidentialityHandler.java:46)
	at io.undertow.servlet.handlers.security.ServletConfidentialityConstraintHandler.handleRequest(ServletConfidentialityConstraintHandler.java:64)
	at io.undertow.security.handlers.AuthenticationMechanismsHandler.handleRequest(AuthenticationMechanismsHandler.java:60)
	at io.undertow.servlet.handlers.security.CachedAuthenticatedSessionHandler.handleRequest(CachedAuthenticatedSessionHandler.java:77)
	at io.undertow.security.handlers.AbstractSecurityContextAssociationHandler.handleRequest(AbstractSecurityContextAssociationHandler.java:43)
	at io.undertow.server.handlers.PredicateHandler.handleRequest(PredicateHandler.java:43)
	at io.undertow.servlet.handlers.SendErrorPageHandler.handleRequest(SendErrorPageHandler.java:52)
	at io.undertow.server.handlers.PredicateHandler.handleRequest(PredicateHandler.java:43)
	at io.undertow.servlet.handlers.ServletInitialHandler.handleFirstRequest(ServletInitialHandler.java:269)
	at io.undertow.servlet.handlers.ServletInitialHandler.access$100(ServletInitialHandler.java:78)
	at io.undertow.servlet.handlers.ServletInitialHandler$2.call(ServletInitialHandler.java:133)
	at io.undertow.servlet.handlers.ServletInitialHandler$2.call(ServletInitialHandler.java:130)
	at io.undertow.servlet.core.ServletRequestContextThreadSetupAction$1.call(ServletRequestContextThreadSetupAction.java:48)
	at io.undertow.servlet.core.ContextClassLoaderSetupAction$1.call(ContextClassLoaderSetupAction.java:43)
	at io.undertow.servlet.handlers.ServletInitialHandler.dispatchRequest(ServletInitialHandler.java:249)
	at io.undertow.servlet.handlers.ServletInitialHandler.access$000(ServletInitialHandler.java:78)
	at io.undertow.servlet.handlers.ServletInitialHandler$1.handleRequest(ServletInitialHandler.java:99)
	at io.undertow.server.Connectors.executeRootHandler(Connectors.java:387)
	at io.undertow.server.HttpServerExchange$1.run(HttpServerExchange.java:841)
	at org.jboss.threads.ContextClassLoaderSavingRunnable.run(ContextClassLoaderSavingRunnable.java:35)
	at org.jboss.threads.EnhancedQueueExecutor.safeRun(EnhancedQueueExecutor.java:2019)
	at org.jboss.threads.EnhancedQueueExecutor$ThreadBody.doRunTask(EnhancedQueueExecutor.java:1558)
	at org.jboss.threads.EnhancedQueueExecutor$ThreadBody.run(EnhancedQueueExecutor.java:1449)
	at java.base/java.lang.Thread.run(Thread.java:844)
Caused by: java.lang.RuntimeException: java.nio.file.NoSuchFileException: /tmp/undertow.12020.9432679758080410942/undertow17157208698492118168upload
	at io.undertow.server.handlers.form.MultiPartParserDefinition$MultiPartUploadHandler.beginPart(MultiPartParserDefinition.java:261)
	at io.undertow.util.MultipartParser$ParseState.headerName(MultipartParser.java:208)
	at io.undertow.util.MultipartParser$ParseState.parse(MultipartParser.java:123)
	at io.undertow.server.handlers.form.MultiPartParserDefinition$MultiPartUploadHandler.parseBlocking(MultiPartParserDefinition.java:232)
	at io.undertow.servlet.spec.HttpServletRequestImpl.parseFormData(HttpServletRequestImpl.java:857)
	at io.undertow.servlet.spec.HttpServletRequestImpl.loadParts(HttpServletRequestImpl.java:579)
	at io.undertow.servlet.spec.HttpServletRequestImpl.getParts(HttpServletRequestImpl.java:530)
	at org.springframework.web.multipart.support.StandardMultipartHttpServletRequest.parseRequest(StandardMultipartHttpServletRequest.java:95)
	... 63 common frames omitted
Caused by: java.nio.file.NoSuchFileException: /tmp/undertow.12020.9432679758080410942/undertow17157208698492118168upload
	at java.base/sun.nio.fs.UnixException.translateToIOException(UnixException.java:92)
	at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:111)
	at java.base/sun.nio.fs.UnixException.rethrowAsIOException(UnixException.java:116)
	at java.base/sun.nio.fs.UnixFileSystemProvider.newByteChannel(UnixFileSystemProvider.java:215)
	at java.base/java.nio.file.Files.newByteChannel(Files.java:369)
	at java.base/java.nio.file.Files.createFile(Files.java:640)
	at java.base/java.nio.file.TempFileHelper.create(TempFileHelper.java:137)
	at java.base/java.nio.file.TempFileHelper.createTempFile(TempFileHelper.java:160)
	at java.base/java.nio.file.Files.createTempFile(Files.java:860)
	at io.undertow.server.handlers.form.MultiPartParserDefinition$MultiPartUploadHandler.beginPart(MultiPartParserDefinition.java:254)
	... 70 common frames omitted
```

# 错误原因
在Linux系统中，Spring Boot应用以`java -jar`命令启动时，会在操作系统的/tmp目录下生成一个tomcat（或undertow），上传的文件先要转换成临时文件保存在这个文件夹下面。由于临时/tmp目录下的文件，在长时间（10天）没有使用的情况下，就会被系统机制自动删除掉。所以如果系统长时间没有使用到临时文件夹，就可能导致上面这个问题。

# 解决方法
## 方法一：临时解决方案
重启SpringBoot应用，即可马上解决问题。

## 方法二：修改 application.yml
在配置文件`applicaiton.yml`里加入配置`spring.servlet.multipart.location`，设置为固定的上传文件目录。
```yml
spring:
  servlet:
    multipart:
      location: /data/app
```

# 参考文章
<https://www.zhangbj.com/p/474.html>
---
title: 'MySQL中Date，夏令时时间转换引发的错误HOUR_OF_DAY: 0 -> 1，及解决办法'
date: 2021-03-25 10:53:15
cover: /images/banner/1004_20240927_021400.webp
coverWidth: 1280
coverHeight: 720
tags: [MySQL,Date,exception,Java,异常,夏令时,时区]
published: true
hideInList: false
feature: 
isTop: false
---
# 做用户导出的功能，代码报错HOUR_OF_DAY: 0 -> 1
* Exception in thread "main" java.lang.IllegalArgumentException: HOUR_OF_DAY: 0 -> 1
详细报错内容如下：

<!-- more -->

```java
org.springframework.orm.jpa.JpaSystemException: could not execute query; nested exception is org.hibernate.exception.GenericJDBCException: could not execute query
	at org.springframework.orm.jpa.vendor.HibernateJpaDialect.convertHibernateAccessException(HibernateJpaDialect.java:331)
	at org.springframework.orm.jpa.vendor.HibernateJpaDialect.translateExceptionIfPossible(HibernateJpaDialect.java:233)
	at org.springframework.orm.jpa.AbstractEntityManagerFactoryBean.translateExceptionIfPossible(AbstractEntityManagerFactoryBean.java:551)
	at org.springframework.dao.support.ChainedPersistenceExceptionTranslator.translateExceptionIfPossible(ChainedPersistenceExceptionTranslator.java:61)
	at org.springframework.dao.support.DataAccessUtils.translateIfNecessary(DataAccessUtils.java:242)
	at org.springframework.dao.support.PersistenceExceptionTranslationInterceptor.invoke(PersistenceExceptionTranslationInterceptor.java:152)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.data.jpa.repository.support.CrudMethodMetadataPostProcessor$CrudMethodMetadataPopulatingMethodInterceptor.invoke(CrudMethodMetadataPostProcessor.java:145)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.aop.interceptor.ExposeInvocationInterceptor.invoke(ExposeInvocationInterceptor.java:97)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.aop.framework.JdkDynamicAopProxy.invoke(JdkDynamicAopProxy.java:215)
	at com.sun.proxy.$Proxy153.findByRaceId(Unknown Source)
	at me.ymq.olympicexport.manager.ExportPoolAllWsManager.exportPoolAll(ExportPoolAllWsManager.java:51)
	at me.ymq.olympicexport.service.ExportPoolAllWsService.queryAll(ExportPoolAllWsService.java:20)
	at me.ymq.olympiccontroller.controller.export.ExportPoolWsController.queryAll(ExportPoolWsController.java:30)
	at me.ymq.olympiccontroller.controller.export.ExportPoolWsController$$FastClassBySpringCGLIB$$73900970.invoke(<generated>)
	at org.springframework.cglib.proxy.MethodProxy.invoke(MethodProxy.java:218)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.invokeJoinpoint(CglibAopProxy.java:779)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:163)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:750)
	at com.alibaba.druid.support.spring.stat.DruidStatInterceptor.invoke(DruidStatInterceptor.java:73)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:750)
	at org.springframework.aop.framework.adapter.MethodBeforeAdviceInterceptor.invoke(MethodBeforeAdviceInterceptor.java:58)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:175)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:750)
	at org.springframework.aop.framework.adapter.MethodBeforeAdviceInterceptor.invoke(MethodBeforeAdviceInterceptor.java:58)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:175)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:750)
	at org.springframework.aop.aspectj.MethodInvocationProceedingJoinPoint.proceed(MethodInvocationProceedingJoinPoint.java:89)
	at me.ymq.olympicaop.aop.framework.LogWsAop.printWsInputAndOutput(LogWsAop.java:38)
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.base/java.lang.reflect.Method.invoke(Method.java:564)
	at org.springframework.aop.aspectj.AbstractAspectJAdvice.invokeAdviceMethodWithGivenArgs(AbstractAspectJAdvice.java:634)
	at org.springframework.aop.aspectj.AbstractAspectJAdvice.invokeAdviceMethod(AbstractAspectJAdvice.java:624)
	at org.springframework.aop.aspectj.AspectJAroundAdvice.invoke(AspectJAroundAdvice.java:72)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:175)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:750)
	at org.springframework.aop.interceptor.ExposeInvocationInterceptor.invoke(ExposeInvocationInterceptor.java:97)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.proceed(CglibAopProxy.java:750)
	at org.springframework.aop.framework.CglibAopProxy$DynamicAdvisedInterceptor.intercept(CglibAopProxy.java:692)
	at me.ymq.olympiccontroller.controller.export.ExportPoolWsController$$EnhancerBySpringCGLIB$$a921ec09.queryAll(<generated>)
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.base/java.lang.reflect.Method.invoke(Method.java:564)
	at org.springframework.web.method.support.InvocableHandlerMethod.doInvoke(InvocableHandlerMethod.java:197)
	at org.springframework.web.method.support.InvocableHandlerMethod.invokeForRequest(InvocableHandlerMethod.java:141)
	at org.springframework.web.servlet.mvc.method.annotation.ServletInvocableHandlerMethod.invokeAndHandle(ServletInvocableHandlerMethod.java:106)
	at org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.invokeHandlerMethod(RequestMappingHandlerAdapter.java:894)
	at org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerAdapter.handleInternal(RequestMappingHandlerAdapter.java:808)
	at org.springframework.web.servlet.mvc.method.AbstractHandlerMethodAdapter.handle(AbstractHandlerMethodAdapter.java:87)
	at org.springframework.web.servlet.DispatcherServlet.doDispatch(DispatcherServlet.java:1060)
	at org.springframework.web.servlet.DispatcherServlet.doService(DispatcherServlet.java:962)
	at org.springframework.web.servlet.FrameworkServlet.processRequest(FrameworkServlet.java:1006)
	at org.springframework.web.servlet.FrameworkServlet.doPost(FrameworkServlet.java:909)
	at javax.servlet.http.HttpServlet.service(HttpServlet.java:517)
	at org.springframework.web.servlet.FrameworkServlet.service(FrameworkServlet.java:883)
	at javax.servlet.http.HttpServlet.service(HttpServlet.java:584)
	at io.undertow.servlet.handlers.ServletHandler.handleRequest(ServletHandler.java:74)
	at io.undertow.servlet.handlers.FilterHandler$FilterChainImpl.doFilter(FilterHandler.java:129)
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
	at io.undertow.servlet.handlers.security.SSLInformationAssociationHandler.handleRequest(SSLInformationAssociationHandler.java:117)
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
Caused by: org.hibernate.exception.GenericJDBCException: could not execute query
	at org.hibernate.exception.internal.StandardSQLExceptionConverter.convert(StandardSQLExceptionConverter.java:47)
	at org.hibernate.engine.jdbc.spi.SqlExceptionHelper.convert(SqlExceptionHelper.java:113)
	at org.hibernate.loader.Loader.doList(Loader.java:2852)
	at org.hibernate.loader.Loader.doList(Loader.java:2831)
	at org.hibernate.loader.Loader.listIgnoreQueryCache(Loader.java:2663)
	at org.hibernate.loader.Loader.list(Loader.java:2658)
	at org.hibernate.loader.hql.QueryLoader.list(QueryLoader.java:506)
	at org.hibernate.hql.internal.ast.QueryTranslatorImpl.list(QueryTranslatorImpl.java:400)
	at org.hibernate.engine.query.spi.HQLQueryPlan.performList(HQLQueryPlan.java:219)
	at org.hibernate.internal.SessionImpl.list(SessionImpl.java:1414)
	at org.hibernate.query.internal.AbstractProducedQuery.doList(AbstractProducedQuery.java:1625)
	at org.hibernate.query.internal.AbstractProducedQuery.list(AbstractProducedQuery.java:1593)
	at org.hibernate.query.Query.getResultList(Query.java:165)
	at org.hibernate.query.criteria.internal.compile.CriteriaQueryTypeQueryAdapter.getResultList(CriteriaQueryTypeQueryAdapter.java:76)
	at org.springframework.data.jpa.repository.query.JpaQueryExecution$CollectionExecution.doExecute(JpaQueryExecution.java:126)
	at org.springframework.data.jpa.repository.query.JpaQueryExecution.execute(JpaQueryExecution.java:88)
	at org.springframework.data.jpa.repository.query.AbstractJpaQuery.doExecute(AbstractJpaQuery.java:155)
	at org.springframework.data.jpa.repository.query.AbstractJpaQuery.execute(AbstractJpaQuery.java:143)
	at org.springframework.data.repository.core.support.RepositoryMethodInvoker.doInvoke(RepositoryMethodInvoker.java:137)
	at org.springframework.data.repository.core.support.RepositoryMethodInvoker.invoke(RepositoryMethodInvoker.java:121)
	at org.springframework.data.repository.core.support.QueryExecutorMethodInterceptor.doInvoke(QueryExecutorMethodInterceptor.java:152)
	at org.springframework.data.repository.core.support.QueryExecutorMethodInterceptor.invoke(QueryExecutorMethodInterceptor.java:131)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.transaction.interceptor.TransactionInterceptor$1.proceedWithInvocation(TransactionInterceptor.java:123)
	at org.springframework.transaction.interceptor.TransactionAspectSupport.invokeWithinTransaction(TransactionAspectSupport.java:388)
	at org.springframework.transaction.interceptor.TransactionInterceptor.invoke(TransactionInterceptor.java:119)
	at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:186)
	at org.springframework.dao.support.PersistenceExceptionTranslationInterceptor.invoke(PersistenceExceptionTranslationInterceptor.java:137)
	... 107 common frames omitted
Caused by: java.sql.SQLException: HOUR_OF_DAY: 0 -> 1
	at com.mysql.cj.jdbc.exceptions.SQLError.createSQLException(SQLError.java:129)
	at com.mysql.cj.jdbc.exceptions.SQLError.createSQLException(SQLError.java:97)
	at com.mysql.cj.jdbc.exceptions.SQLError.createSQLException(SQLError.java:89)
	at com.mysql.cj.jdbc.exceptions.SQLError.createSQLException(SQLError.java:63)
	at com.mysql.cj.jdbc.exceptions.SQLError.createSQLException(SQLError.java:73)
	at com.mysql.cj.jdbc.exceptions.SQLExceptionsMapping.translateException(SQLExceptionsMapping.java:85)
	at com.mysql.cj.jdbc.result.ResultSetImpl.getTimestamp(ResultSetImpl.java:933)
	at com.mysql.cj.jdbc.result.ResultSetImpl.getTimestamp(ResultSetImpl.java:971)
	at com.alibaba.druid.filter.FilterChainImpl.resultSet_getTimestamp(FilterChainImpl.java:1258)
	at com.alibaba.druid.filter.FilterAdapter.resultSet_getTimestamp(FilterAdapter.java:1829)
	at com.alibaba.druid.filter.FilterChainImpl.resultSet_getTimestamp(FilterChainImpl.java:1254)
	at com.alibaba.druid.filter.FilterAdapter.resultSet_getTimestamp(FilterAdapter.java:1829)
	at com.alibaba.druid.filter.FilterChainImpl.resultSet_getTimestamp(FilterChainImpl.java:1254)
	at com.alibaba.druid.proxy.jdbc.ResultSetProxyImpl.getTimestamp(ResultSetProxyImpl.java:740)
	at com.alibaba.druid.pool.DruidPooledResultSet.getTimestamp(DruidPooledResultSet.java:365)
	at org.hibernate.type.descriptor.sql.TimestampTypeDescriptor$2.doExtract(TimestampTypeDescriptor.java:84)
	at org.hibernate.type.descriptor.sql.BasicExtractor.extract(BasicExtractor.java:47)
	at org.hibernate.type.AbstractStandardBasicType.nullSafeGet(AbstractStandardBasicType.java:257)
	at org.hibernate.type.AbstractStandardBasicType.nullSafeGet(AbstractStandardBasicType.java:253)
	at org.hibernate.type.AbstractStandardBasicType.nullSafeGet(AbstractStandardBasicType.java:243)
	at org.hibernate.type.AbstractStandardBasicType.hydrate(AbstractStandardBasicType.java:329)
	at org.hibernate.persister.entity.AbstractEntityPersister.hydrate(AbstractEntityPersister.java:3130)
	at org.hibernate.loader.Loader.loadFromResultSet(Loader.java:1869)
	at org.hibernate.loader.Loader.hydrateEntityState(Loader.java:1797)
	at org.hibernate.loader.Loader.instanceNotYetLoaded(Loader.java:1770)
	at org.hibernate.loader.Loader.getRow(Loader.java:1622)
	at org.hibernate.loader.Loader.getRowFromResultSet(Loader.java:740)
	at org.hibernate.loader.Loader.getRowsFromResultSet(Loader.java:1039)
	at org.hibernate.loader.Loader.processResultSet(Loader.java:990)
	at org.hibernate.loader.Loader.doQuery(Loader.java:959)
	at org.hibernate.loader.Loader.doQueryAndInitializeNonLazyCollections(Loader.java:349)
	at org.hibernate.loader.Loader.doList(Loader.java:2849)
	... 132 common frames omitted
Caused by: com.mysql.cj.exceptions.WrongArgumentException: HOUR_OF_DAY: 0 -> 1
	at java.base/jdk.internal.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
	at java.base/jdk.internal.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:62)
	at java.base/jdk.internal.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
	at java.base/java.lang.reflect.Constructor.newInstance(Constructor.java:488)
	at com.mysql.cj.exceptions.ExceptionFactory.createException(ExceptionFactory.java:61)
	at com.mysql.cj.exceptions.ExceptionFactory.createException(ExceptionFactory.java:105)
	at com.mysql.cj.result.SqlTimestampValueFactory.localCreateFromDate(SqlTimestampValueFactory.java:102)
	at com.mysql.cj.result.SqlTimestampValueFactory.localCreateFromDate(SqlTimestampValueFactory.java:51)
	at com.mysql.cj.result.AbstractDateTimeValueFactory.createFromDate(AbstractDateTimeValueFactory.java:69)
	at com.mysql.cj.protocol.a.MysqlTextValueDecoder.decodeDate(MysqlTextValueDecoder.java:77)
	at com.mysql.cj.protocol.result.AbstractResultsetRow.decodeAndCreateReturnValue(AbstractResultsetRow.java:92)
	at com.mysql.cj.protocol.result.AbstractResultsetRow.getValueFromBytes(AbstractResultsetRow.java:243)
	at com.mysql.cj.protocol.a.result.ByteArrayRow.getValue(ByteArrayRow.java:91)
	... 158 common frames omitted
Caused by: java.lang.IllegalArgumentException: HOUR_OF_DAY: 0 -> 1
	at java.base/java.util.GregorianCalendar.computeTime(GregorianCalendar.java:2826)
	at java.base/java.util.Calendar.updateTime(Calendar.java:3425)
	at java.base/java.util.Calendar.getTimeInMillis(Calendar.java:1812)
	at com.mysql.cj.result.SqlTimestampValueFactory.localCreateFromDate(SqlTimestampValueFactory.java:100)
	... 164 common frames omitted
```

MySQL中生日字段是Date类型，这个看起来是没有错的，报错的再进一步的位置是 mysql.jar，MySQL中的驱动报错。
```java
import java.util.Calendar;
import java.util.Date;
public class Test {
    public static void main(String[] args) {
            Calendar cal=Calendar.getInstance();
            cal.setLenient(false);
            cal.set(1991,3,14,0,0,0);
            System.out.println(cal.getTime());
    }

}
```

拿出来测试，报错。
`cal.setLenient(false);` 这个是严格模式，设置成`true`，设置成不严格模式就是通过的。

严格模式做的事情，设置成严格模式，有两个校验，

> 第一个校验，时间是0-24点，设置成25点会报错。
> 第二个校验是各个时间的夏令时其他的日历的校验。

下面是我国曾经使用过的夏令时列表
![](https://img-blog.csdn.net/20181010164425291)

* 也就是说，只要用户生日是`1986年5月4日`，`1987年4月12日`，`1988年4月10日`，`1989年4月16日`，`1990年4月15日`，`1989年4月14日`，`MySQL`就会报错，因为这些日子都不存在`0点0分0秒` -_-!

# 解决办法
1. 在 MySQL 的连接参数上加入`useLegacyDatetimeCode=false`和`serverTimezone=Asia/Shanghai`
2. 将代码里面的生日类型从`Date`改为`LocalDate`，把原来使用的`糊涂工具包`里面的`DateUtil`换为`LocalDateTimeUtil`

# 官方文档
<https://dev.mysql.com/doc/connector-j/5.1/en/connector-j-reference-configuration-properties.html>
![](https://img-blog.csdnimg.cn/img_convert/a2f5da074e7af9c9010c3c694894f8f9.png)

# 参考文章
<https://blog.csdn.net/u014510302/article/details/82999412>
<https://blog.csdn.net/weixin_39988476/article/details/113350287>
<http://www.voidcn.com/article/p-eqvuhiio-bsb.html>
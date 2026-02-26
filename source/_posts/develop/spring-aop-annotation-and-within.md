---
title: 【转】Spring AOP 拦截指定注解标识的类或方法
tags:
  - java
  - spring
  - aop
  - annotation
  - springboot
published: true
hideInList: false
isTop: false
categories:
  - develop
date: 2021-01-14 15:29:41
feature:
---
AOP中扫描指定注解相关说明
（1）@annotation：用来拦截所有被某个注解修饰的方法
（2）@within：用来拦截所有被某个注解修饰的类
（3）within：用来指定扫描的包的范围

<!-- more -->
# 代码Demo
```java
@Aspect
@Component
@Order(10)
public class BidAuthorityProxy {
    /**
     * 扫描指定包下的类中使用@EnableRoleAuthority注解修饰的类
     */
    @Around("@within(com.core.annotation.EnableRoleAuthority) && within(com.bid..*)")
    public Object verifyRoleExecuteCommand(ProceedingJoinPoint pjp) throws Throwable {
        // 获取当前拦截方法的对象
        MethodSignature msig = (MethodSignature) pjp.getSignature();
        Method targetMethod = pjp.getTarget().getClass().getDeclaredMethod(msig.getName(), msig.getMethod().getParameterTypes());
 
        // 获取当前方法注解中的值
        VerifyRoleAuthority annotation = targetMethod.getAnnotation(VerifyRoleAuthority.class);
 
        // 如果类上面没有注解，则获取接口上此方法的注解
        if (annotation == null) {
            Class<?>[] inters = pjp.getTarget().getClass().getInterfaces();
            for (Class<?> inter : inters) {
                Method targetInterMethod = inter.getDeclaredMethod(msig.getName(), msig.getMethod().getParameterTypes());
                annotation = targetInterMethod.getAnnotation(VerifyRoleAuthority.class);
                if (annotation != null) {
                    break;
                }
            }
        }
 
        // 获取到注解中的值后进行后续自定义逻辑操作
        return pjp.proceed();// 执行方法
    }
}
```

`来源`
<https://blog.csdn.net/java_faep/article/details/104005399>
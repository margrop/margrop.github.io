---
title: '修复 SpringFox 3.0.0 不兼容 SpringBoot 2.6.4 的问题'
date: 2023-03-12 17:56:57
tags: [Java,spring,springfox,springboot]
published: true
hideInList: false
feature: 
isTop: false
---
# 异常提示：
```
Failed to start bean 'documentationPluginsBootstrapper'; nested exception is java.lang.NullPointerException
```

# 原因分析：
`SpringFox` 3.0.0 不兼容 `SpringBoot` 2.6.4

# 解决方案：
* 参考链接
<https://stackoverflow.com/questions/40241843/failed-to-start-bean-documentationpluginsbootstrapper-in-spring-data-rest>
<https://github.com/springfox/springfox/issues/3462#issuecomment-1010721223>

<!-- more -->

1. set `spring.mvc.pathmatch.matching-strategy: ant_path_matcher`  in `application.properties`
2. add this bean
```
@Bean
public WebMvcEndpointHandlerMapping webEndpointServletHandlerMapping(WebEndpointsSupplier webEndpointsSupplier, ServletEndpointsSupplier servletEndpointsSupplier, ControllerEndpointsSupplier controllerEndpointsSupplier, EndpointMediaTypes endpointMediaTypes, CorsEndpointProperties corsProperties, WebEndpointProperties webEndpointProperties, Environment environment) {
        List<ExposableEndpoint<?>> allEndpoints = new ArrayList();
        Collection<ExposableWebEndpoint> webEndpoints = webEndpointsSupplier.getEndpoints();
        allEndpoints.addAll(webEndpoints);
        allEndpoints.addAll(servletEndpointsSupplier.getEndpoints());
        allEndpoints.addAll(controllerEndpointsSupplier.getEndpoints());
        String basePath = webEndpointProperties.getBasePath();
        EndpointMapping endpointMapping = new EndpointMapping(basePath);
        boolean shouldRegisterLinksMapping = this.shouldRegisterLinksMapping(webEndpointProperties, environment, basePath);
        return new WebMvcEndpointHandlerMapping(endpointMapping, webEndpoints, endpointMediaTypes, corsProperties.toCorsConfiguration(), new EndpointLinksResolver(allEndpoints, basePath), shouldRegisterLinksMapping, null);
    }


private boolean shouldRegisterLinksMapping(WebEndpointProperties webEndpointProperties, Environment environment, String basePath) {
        return webEndpointProperties.getDiscovery().isEnabled() && (StringUtils.hasText(basePath) || ManagementPortType.get(environment).equals(ManagementPortType.DIFFERENT));
    }
```
---
title: 使用 OpenResty + 签名 Cookie 实现登录一次即可长时间免认证的反代安全网关
date: 2026-02-28 18:05:00
categories:
- AI Tech
tags:
- 技术
- 安全
- OpenResty
- 反向代理
- 认证
cover: https://picsum.photos/seed/20260228auth/1280/720
coverWidth: 1280
coverHeight: 720
---

## 前言

在日常运维工作中，我们经常需要暴露一些 Web 面板或管理后台到公网，方便随时随地访问。然而，公网暴露端口容易被扫描和爆破，给系统带来安全隐患。最近各类 Web 应用的安全事件频发，如何在不修改原应用的情况下，为这些服务增加一层安全防护，成为了一个值得思考的问题。

本文将介绍一种轻量级的加固方案：使用 OpenResty 搭建反向代理网关，通过 BasicAuth 进行首次认证，结合签名 Cookie 实现 1 小时免重复认证。整个方案不需要修改原应用容器，不依赖 Redis 或数据库，完全无状态。

## 问题背景

很多常见的 Web 面板和管理后台都存在以下问题：

### 1. 端口直接暴露

很多应用默认监听所有网络接口，导致端口直接暴露在公网。这意味着任何人都可以尝试访问你的服务，增加了被攻击的风险。

### 2. 弱密码风险

有些应用的默认账号密码非常简单，或者用户设置的密码强度不够，很容易被暴力破解。

### 3. 频繁验证繁琐

如果每次访问都需要输入密码验证，会严重影响使用体验。特别是对于需要频繁访问的管理后台来说，重复认证非常麻烦。

### 4. 改造成本高

对原应用进行安全改造需要投入大量时间和精力，而且可能会引入新的问题。

## 解决方案概述

针对以上问题，我设计了一套基于 OpenResty 的反向代理认证网关方案。这套方案的核心思想是：在不改原应用的情况下，通过网关层实现统一的认证控制。

### 方案特点

- **不改原应用**：所有认证逻辑都在网关层实现，不需要修改任何应用代码
- **首次 BasicAuth**：首次访问时弹出认证对话框，输入正确的用户名密码后即可进入
- **签名 Cookie**：认证成功后生成带有签名的 Cookie，有效期内无需重复认证
- **无状态设计**：不依赖任何外部存储（Redis、数据库等），容器重启不影响认证状态
- **支持 WebSocket**：完整支持 WebSocket 连接，可以用于各类实时应用

### 技术选型

为什么选择 OpenResty？主要有以下考虑：

1. **高性能**：基于 Nginx，性能出色
2. **Lua 支持**：内置 Lua 支持，可以灵活实现各种逻辑
3. **模块丰富**：社区提供了大量实用的模块
4. **易于部署**：官方提供 Alpine 镜像，体积小巧

## 架构设计

### 网络架构

整体架构可以分为三层：

```
公网入口 → OpenResty 网关 → 内部应用
```

具体流程如下：

1. 用户访问公网地址
2. 请求首先到达 OpenResty 网关
3. 网关检查是否存在有效的签名 Cookie
4. 如果没有 Cookie 或 Cookie 已过期，跳转到登录页面
5. 用户在登录页面完成 BasicAuth 认证
6. 认证成功后，网关生成签名 Cookie 并跳转到目标页面
7. 之后 1 小时内访问同一页面无需再次认证

### 组件说明

整个方案包含两个核心组件：

**内部应用容器**：这是你需要保护的服务，比如某管理面板。它只监听容器内部端口 127.0.0.1，不直接暴露到公网。

**OpenResty 网关**：反向代理服务器，负责所有外部请求的接入、认证检查和 Cookie 签名验证。

## 核心实现

### Docker Compose 配置

首先来看完整的 Docker Compose 配置文件。这个文件定义了内部应用和 OpenResty 网关两个服务。

```yaml
services:
  app:
    image: your-app-image:tag
    container_name: app
    restart: always
    ports:
      - "127.0.0.1:内部端口:内部端口"
    networks:
      - ql_net

  openresty:
    image: openresty/openresty:alpine
    container_name: secure-gateway
    restart: always
    depends_on:
      - app
    ports:
      - "外网端口:80"
    environment:
      COOKIE_SECRET: "your_long_random_secret"
      COOKIE_NAME: "ql_auth"
      COOKIE_TTL: "3600"
    volumes:
      - ./nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro
      - ./.htpasswd:/etc/openresty/.htpasswd:ro
    networks:
      - ql_net

networks:
  ql_net:
    driver: bridge
```

关键点说明：

- 内部应用端口绑定到 127.0.0.1，确保只能从容器内部访问
- OpenResty 通过环境变量配置 Cookie 签名密钥、名称和过期时间
- 使用 Docker 内置 DNS 实现容器名解析

### Nginx 配置详解

接下来是核心的 Nginx 配置文件。这个配置实现了完整的认证流程。

#### 1. HTTP 和事件配置

```nginx
worker_processes 1;
events {
    worker_connections 1024;
}
http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    
    # Docker 内置 DNS
    resolver 127.0.0.11 ipv6=off valid=30s;
    
    # WebSocket 支持
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
    # 省略部分配置...
}
```

这里使用了 Docker 内置的 DNS 解析器，可以根据容器名自动解析 IP 地址。WebSocket 的支持通过 map 指令实现 Connection 头的转换。

#### 2. 登录入口实现

```nginx
location = /__login {
    auth_basic "Restricted";
    auth_basic_user_file /etc/openresty/.htpasswd;
    
    content_by_lua_block {
        local secret = os.getenv("COOKIE_SECRET")
        local cookie_name = os.getenv("COOKIE_NAME")
        local ttl = tonumber(os.getenv("COOKIE_TTL"))
        
        -- HMAC-SHA1 签名
        local function sign(payload)
            return to_hex(ngx.hmac_sha1(secret, payload))
        end
        
        -- 生成过期时间戳
        local exp = ngx.time() + ttl
        local payload = tostring(exp)
        
        -- 生成签名 Cookie
        local token = payload .. "." .. sign(payload)
        
        -- 设置 Cookie 头
        ngx.header["Set-Cookie"] = cookie_name .. "=" .. token .. 
            "; Path=/; Max-Age=" .. ttl .. 
            "; HttpOnly; SameSite=Lax"
        
        -- 登录成功后跳转
        return ngx.redirect(ngx.var.arg_next or "/", 302)
    }
}
```

登录入口的特点：

- 只在 /__login 路径触发 BasicAuth 认证
- 使用 HMAC-SHA1 算法对过期时间戳进行签名
- Cookie 设置为 HttpOnly，防止 JavaScript 读取
- 使用 SameSite=Lax 减少 CSRF 风险

#### 3. 主入口验证逻辑

```nginx
location / {
    access_by_lua_block {
        -- 校验签名 Cookie
        local token = ngx.var["cookie_ql_auth"]
        
        if token then
            local dot = token:find("%.")
            local payload = token:sub(1, dot - 1)
            local sig = token:sub(dot + 1)
            
            -- 验签并检查过期
            if sig == sign(payload) then
                local exp = tonumber(payload)
                if exp and exp > ngx.time() then
                    ok = true
                end
            end
        end
        
        -- 未通过验证则跳转登录
        if not ok then
            return ngx.redirect("/__login?next=" .. ngx.escape_uri(request_uri), 302)
        end
    }
    
    -- 反向代理到内部应用
    proxy_pass http://app:内部端口;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    
    -- WebSocket 支持
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
}
```

主入口的验证流程：

1. 读取请求中的 Cookie
2. 解析出 payload（过期时间戳）和 signature（签名）
3. 使用相同的密钥重新计算签名并比对
4. 检查当前时间是否超过过期时间
5. 验证通过后允许访问，否则跳转到登录页

#### 4. 退出登录（可选）

```nginx
location = /__logout {
    content_by_lua_block {
        -- 清除 Cookie
        ngx.header["Set-Cookie"] = "ql_auth=deleted; Path=/; Max-Age=0"
        return ngx.redirect("/", 302)
    }
}
```

## 部署步骤

### 第一步：准备目录结构

首先创建所需的目录：

```bash
mkdir -p /docker/yourapp/openresty
mkdir -p /docker/yourapp/data
```

### 第二步：生成认证文件

使用 Apache 的 htpasswd 工具生成 BasicAuth 所需的账号密码文件：

```bash
docker run --rm httpd:2.4-alpine \
    htpasswd -nbB username 'strong_password' \
    > /docker/yourapp/openresty/.htpasswd
```

### 第三步：生成 Cookie 签名密钥

使用 Python 生成一个随机的长字符串作为签名密钥：

```bash
python3 -c "import base64; print(base64.b64encode(__import__('os').urandom(48)).decode())"
```

将生成的密钥填入 docker-compose.yml 的 COOKIE_SECRET 环境变量。

### 第四步：编写配置文件

将前面介绍的 nginx.conf 和 docker-compose.yml 文件写入对应目录。

### 第五步：启动服务

```bash
cd /docker/yourapp
docker compose up -d
```

### 第六步：验证效果

1. 首次访问：浏览器自动跳转到 /__login 页面
2. 弹出 BasicAuth 对话框，输入账号密码
3. 认证成功后自动跳转到目标页面
4. 在 1 小时内刷新页面，无需再次认证
5. 访问 /__logout 可以立即退出登录

## 常见错误排查

### 错误一：map 指令位置错误

错误信息：map directive is not allowed here

原因：map 指令放在了 server 块内部，而不是 http 块级别。

解决：将 map 指令移到 http {} 块内部。

### 错误二：缺少 HMAC 模块

错误信息：module 'resty.hmac' not found

原因：使用了第三方 HMAC 模块，但镜像中没有安装。

解决：使用 OpenResty 内置的 ngx.hmac_sha1() 函数，无需额外模块。

### 错误三：Cookie 签名验证失败

可能原因：

- COOKIE_SECRET 不一致（多实例环境）
- Cookie 被篡改
- 时间不同步

解决：确保所有网关使用相同的签名密钥，检查服务器时间是否准确。

## 安全建议

虽然这套方案可以显著提升安全性，但仍有一些最佳实践需要注意：

### 1. 限制来源 IP

在云平台的安全组中，只放行你自己的公网 IP 地址。这是最有效的防护手段。

### 2. 修改登录路径

将默认的 /__login 路径改为随机的长路径，降低被扫描命中的概率。

### 3. 配置访问限流

配置 Nginx 的限流规则，防止暴力破解。

### 4. 启用 HTTPS

生产环境建议启用 HTTPS，确保所有通信都经过加密。BasicAuth 的账号密码和签名的 Cookie 都不应该明文传输。

### 5. 定期更换密钥

定期更换 COOKIE_SECRET，可以进一步提升安全性。换密钥后所有已登录用户需要重新认证。

## 性能考量

### 1. Cookie 验证开销

Cookie 验证过程涉及 HMAC-SHA1 计算，对于现代 CPU 来说这个开销可以忽略不计。每秒处理数万请求毫无压力。

### 2. 内存占用

OpenResty 的内存占用非常低， Alpine 镜像只有几十 MB。Lua 脚本的内存占用也很小。

### 3. 连接复用

配置了 keepalive_timeout，可以复用与后端应用的连接，减少连接建立的开销。

## 应用场景

这套方案适合以下场景：

- 各类需要认证的 Web 管理面板
- 需要临时暴露给特定人员的内部系统
- 开发测试环境的快速安全加固
- 不想修改原应用的任何代码的情况

不适合以下场景：

- 对安全性要求极高的金融系统
- 需要细粒度权限控制的应用
- 需要记录详细审计日志的场景

## 总结

这套基于 OpenResty 和签名 Cookie 的认证网关方案，具有以下优势：

1. **轻量级**：不需要额外的认证服务，不依赖数据库
2. **无状态**：认证信息存储在客户端 Cookie 中，服务器不需要保存会话
3. **高安全**：使用 HMAC-SHA1 签名防止 Cookie 篡改
4. **易部署**：完全通过配置文件实现，不需要编写代码
5. **灵活可控**：Cookie 过期时间可随意设置

通过这套方案，我们可以快速将暴露在公网的各类 Web 面板从"裸奔"状态提升到"可控暴露"状态，既保证了安全性，又不影响使用体验。

如果你也有类似的安全加固需求，不妨试试这个方案。

---

## 🎁 MiniMax 跨年福利来袭！

邀好友享 Coding Plan 双重好礼，助力开发体验！

- 好友立享 **9折** 专属优惠 + Builder 权益
- 你赢返利 + 社区特权

👉 立即参与：https://platform.minimaxi.com/subscribe/coding-plan?code=8Ah4UZHvZ0&source=link

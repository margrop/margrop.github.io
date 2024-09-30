---
title: '安装 minikube-dashboard + 自动启动和外网访问'
date: 2024-04-30 19:42:36
tags: [k8s]
published: true
hideInList: false
feature: 
isTop: false
---
# 一、安装 minikube-dashboard
> 参考官网文档：<https://minikube.sigs.k8s.io/docs/start/>
> 执行命令 `minikube dashboard`

# 二、安装 minikube 后台服务 
如果你希望 `minikube` 在 `systemctl` 管理下只启动一次，并且在启动成功后自动退出，你可以调整 `systemctl` 的服务文件，使其不会自动重启 `minikube`。这可以通过设置 `Restart=no` 来实现，并确保服务只在需要时手动启动。

下面是一个基本的 `systemctl` 服务文件示例，适用于这种情况：
<!-- more -->
```ini
#minikube自启动脚本
#/etc/systemd/system/minikube.service

[Unit]
Description=Minikube Kubernetes
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=root
RemainAfterExit=yes
Environment="HOME=/root"
Environment="MINIKUBE_HOME=/root/.minikube"
ExecStart=/usr/local/bin/minikube start --force

[Install]
WantedBy=multi-user.target
```

### 解释

- **Type=oneshot**：这表明服务是一次性的，即执行一次后就认为已经完成。这对于执行脚本或命令非常有用，这些脚本或命令在执行完后不需要保持运行状态。
  
- **RemainAfterExit=yes**：即使服务的主进程已退出，也认为此服务仍然是活跃的。这对于 `minikube` 启动完毕后适用，因为它不需要持续运行一个后台进程。

- **Restart=no**：这表示如果服务退出，不论成功还是失败，`systemd` 都不会尝试重启服务。

### 使用步骤

1. **创建服务文件**：将上述内容保存到 `/etc/systemd/system/minikube.service`。

2. **重载 `systemd` 配置**：更新 `systemd` 以识别你的新服务或服务文件的更改。
   ```bash
   sudo systemctl daemon-reload
   ```

3. **启动服务**：使用 `systemctl` 启动 `minikube` 服务。
   ```bash
   sudo systemctl start minikube.service
   ```

4. **检查状态**：验证服务的状态，确保没有错误。
   ```bash
   sudo systemctl status minikube.service
   ```

5. **启用服务**：如果希望在系统启动时自动运行 Minikube（只执行一次，然后退出），可以启用服务。
   ```bash
   sudo systemctl enable minikube.service
   ```

这样配置后，Minikube 将在系统启动时运行一次并初始化完成后退出，但不会再自动重启。

# 三、安装 minikube-dashboard 后台服务 
* 步骤同上，这里不再重复，将简化操作说明
* 编辑文件 `/etc/systemd/system/minikube-dashboard.service`
```ini
#Minikube自启动并自动映射 dashboard 端口
#/etc/systemd/system/minikube-dashboard.service

[Unit]
Description=Auto-start Kubernetes Dashboard with port-forwarding
After=minikube.service
Requires=minikube.service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Environment="HOME=/root"
Environment="MINIKUBE_HOME=/root/.minikube"
ExecStartPre=kubectl wait --for=condition=ready pod --selector=k8s-app=kubernetes-dashboard -n kubernetes-dashboard --timeout=120s
ExecStart=/bin/bash -c 'kubectl port-forward --address 0.0.0.0 service/kubernetes-dashboard 8080:80 -n kubernetes-dashboard'
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```
* 常规服务操作
```bash
#重载服务配置
sudo systemctl daemon-reload
#配置自启动
sudo systemctl enable minikube-dashboard.service
#手工启动服务
sudo systemctl start minikube-dashboard.service
#查看服务状态
sudo systemctl status minikube-dashboard.service
```

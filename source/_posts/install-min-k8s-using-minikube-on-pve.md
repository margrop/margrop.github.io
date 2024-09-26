---
title: '使用 Minikube 安装最小化k8s环境'
date: 2024-04-30 19:37:29
tags: [k8s,Proxmox VE,pve]
published: true
hideInList: false
feature: 
isTop: false
---
在 Proxmox VE（一种基于 Debian 的虚拟化环境）上部署 Minikube 需要考虑 Proxmox 的特性，它本质上是一个虚拟机和容器管理平台。您将需要在 Proxmox VE 上创建一个虚拟机（VM），然后在该 VM 中安装 Minikube。以下是详细的步骤：

<!-- more -->

### 步骤 1: 创建并配置虚拟机

1. **登录 Proxmox VE 管理界面**：
   - 通常通过 Web 浏览器访问 `https://<Proxmox_IP>:8006`。

2. **创建一个新的虚拟机**：
   - 在 Proxmox 的 "Create VM" 按钮中点击。
   - 为 VM 命名，选择安装类型为 "Linux"，版本根据您要安装的 Linux 发行版确定（推荐使用 Ubuntu 或 Debian）。

3. **配置硬件**：
   - **CPU**: 至少分配 2 核心。
   - **内存**: 至少分配 2GB RAM。
   - **硬盘**: 至少 20GB 存储空间。
   - **网络**: 确保 VM 可以访问互联网。

4. **安装操作系统**：
   - 挂载 ISO 文件并通过 Proxmox 的控制台进行操作系统的安装。
   - 安装过程中设置必要的用户和网络配置。

### 步骤 2: 安装和配置 Minikube

1. **连接到虚拟机**：
   - 使用 SSH 或通过 Proxmox 的控制台连接到新创建的 VM。

2. **安装 kubectl**：
   - 在 VM 上安装 `kubectl`。对于 Ubuntu/Debian 系统，可以使用以下命令：
     ```bash
     curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
     chmod +x ./kubectl
     sudo mv ./kubectl /usr/local/bin/kubectl
     kubectl version --client
     ```

3. **安装 Minikube**：
   - 下载并安装 Minikube。对于 Linux 系统，可以使用以下命令：
     ```bash
     curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
     chmod +x minikube
     sudo install minikube /usr/local/bin/
     ```

4. **启动 Minikube**：
   - 由于在 VM 中运行，推荐使用 Docker 作为驱动器。首先确保 Docker 已安装，并启动 Minikube：
     ```bash
     minikube start --driver=docker
     ```
   - 这一步会自动拉取必要的 Minikube Docker 镜像并启动 Kubernetes 集群。

5. **验证安装**：
   - 运行 `kubectl get nodes` 来检查集群状态，应该显示 minikube 节点处于 READY 状态。

### 步骤 3: 配置和使用 Kubernetes 集群

- 通过 `kubectl` 命令与集群交互，部署应用程序或进行其他管理任务。
- 如果需要访问集群内运行的应用程序，可以使用 Minikube 的 `minikube service` 命令来暴露服务。

通过上述步骤，您可以在 Proxmox VE 上成功部署和运行一个 Minikube Kubernetes 集群，为开发和测试环境提供一个相对隔离且资源可控的环境。











---
title: 'Mac编译N2N组件SuperNode和Edge'
date: 2021-11-09 20:21:05
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 参考：https://www.jianshu.com/p/5021b70c3ff9

# 使用Brew安装必要软件
```
brew install openssl
brew tap homebrew/cask
brew install --cask tuntap
```

<!-- more -->


> 提示：如果命令行提示安装 `tuntap` 失败，请进入系统设置中的`Security & Privacy`，选择`Allow`

# 从Github clone并且编译
```
cd ~
git clone  https://github.com/ntop/n2n 
cd n2n
git checkout 2.8-stable
mkdir build
cd build
cmake ..
make
```

# 将Edge复制到 /usr/local/bin/edge 并给予可执行权限
```
cp edge /usr/local/bin/
chmod +x /usr/local/bin/edge
```

# 测试是否能正常启动
```
./edge -a 10.0.0.1 -c EfIvHDDSWEW3QM -k EfIvHDDSWEW3QM -l 127.0.0.1:2345 -v -f
sudo edge -a 10.0.0.10 -c EfIvHDDSWEW3QM -k EfIvHDDSWEW3QM -l blog.margrop.net:2345 -v -f
```

# edgesh.sh
```
#/bin/bash
ps -e | grep "edge -a" | awk '{print $1}' | xargs sudo kill
sudo edge -a 10.0.0.1 -c MAC -k EfIvHDDSWEW3QM -l blog.margrop.net:2345-v -r

sudo route -v delete -net 192.168.1.0 -gateway 10.0.0.1
sudo route -v delete -net 192.168.2.0 -gateway 10.0.0.2

sudo route -n add -net 192.168.1.0 -netmask 255.255.255.0 10.0.0.1
sudo route -n add -net 192.168.2.0 -netmask 255.255.255.0 10.0.0.2
ping 192.168.1.1 -c 3
ping 192.168.2.1 -c 3
ping 10.0.0.1 -c 3
```
---
title: '使用ffmpeg批量删除音视频的片头片尾'
date: 2023-04-02 11:51:41
tags: []
published: true
hideInList: false
feature: 
isTop: false
---
# 步骤
## 1. 下载ffmpeg
* 步骤略

## 2. 编辑Bat脚本
```bat
@echo off & setlocal enabledelayedexpansion

rem ===================需手动设置===================
rem 设定片头片尾长度，格式为 HH:mm:ss.fff
set "s1=00:01:07.0"
set "s2=00:01:30.0"
rem ================================================

for /f "tokens=1-4delims=:." %%a in ("%s2%") do (
    set /a "t2=(1%%a %% 100 *3600 + 1%%b %% 100 * 60 + 1%%c %% 100) * 1000 + 1%%d %% 1000"
)

md myvideo 2>nul
for %%i in (*.avi *.mkv *.mp4 *.flv) do (
    for /f "tokens=2-5delims=:., " %%a in ('ffmpeg -i "%%i" 2^>^&1 ^| find "Duration:"') do (
        set /a "t=(1%%a%%100*3600+1%%b%%100*60+1%%c%%100)*1000+1%%d0%%1000,t-=t2,ms=t%%1000,t/=1000"
        set /a h=t/3600,m=t%%3600/60,s=t%%60,h+=100,m+=100,s+=100,ms+=1000
        set "t=!h:~1!:!m:~1!:!s:~1!.!ms:~1!"
        ffmpeg -ss !s1! -to !t! -accurate_seek -i "%%i"  -c copy -avoid_negative_ts 1 "myvideo\%%i" -y
    )
)
pause
```

<!-- more -->

## 3. 运行bat脚本

# 来源
<https://blog.zhheo.com/p/4f4d0864.html>
<https://wwa.lanzoui.com/i65Ucnq7kta>原作者分享链接，密码：6fpt
<https://zhheo.lanzouo.com/iZ7PNxftu2j>防丢博主备份链接

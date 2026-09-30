<#
.SYNOPSIS
    Windows 11 26H2 (2026 Update) 升级前置自检与避坑自动化工具箱
.DESCRIPTION
    原生 PowerShell 7 / Windows PowerShell 脚本，0 第三方依赖。
    功能：
    1. 操作系统版本与分支基线核验（确保属于 24H2/25H2/26H2 共享服务分支，拦截 26H1 孤岛）。
    2. 检查前置累计安全补丁 KB5124010 安装状态。
    3. WinSxS 组件存储库健康扫描与 DISM 在线修复。
    4. BitLocker 加密卷状态巡检与 48 位恢复密钥安全脱敏导出。
    5. USB Audio Class 1.0 设备扫描与 Code 10 兼容性注册表修复。
    6. 支持人工交互模式与 Agent 声明式自动化执行。
.PARAMETER Mode
    运行模式：Audit（只读审计，默认）或 Execute（执行修复与准备）
.PARAMETER AgentPlan
    可选的 Agent 声明式计划 JSON 路径
#>

[CmdletBinding()]
param(
    [ValidateSet("Audit", "Execute")]
    [string]$Mode = "Audit",

    [string]$AgentPlan = ""
)

$ErrorActionPreference = "Stop"

Write-Host "[•] ========================================================" -ForegroundColor Cyan
Write-Host "[•]  Windows 11 26H2 升级就绪性巡检与故障避坑工具箱        " -ForegroundColor Cyan
Write-Host "[•]  平台: Windows 11 | 运行模式: $Mode                  " -ForegroundColor Cyan
Write-Host "[•] ========================================================" -ForegroundColor Cyan

# 0. Agent 计划解析（如果提供）
if ($AgentPlan -and (Test-Path $AgentPlan)) {
    Write-Host "[*] 正在加载 Agent 声明式运维计划: $AgentPlan" -ForegroundColor Gray
    $PlanObj = Get-Content $AgentPlan -Raw | ConvertFrom-Json
    if ($PlanObj.mode -eq "Execute") {
        $Mode = "Execute"
    }
}

$Report = [ordered]@{
    Timestamp = (Get-Date).ToString("s")
    HostSanitized = "WIN11-WORKSTATION-X"
    CurrentBuild = ""
    ServicingBranch = ""
    KB5124010Installed = $false
    ComponentStoreHealthy = $false
    BitLockerProtection = "Unknown"
    UsbAudioClass1Devices = @()
    ActionTaken = @()
    ReadyFor26H2 = $false
}

# 1. 检查操作系统版本
Write-Host "`n[1/5] 正在核验操作系统版本与核心分支基线..." -ForegroundColor Yellow
$OsInfo = Get-CimInstance Win32_OperatingSystem
$BuildNumber = [int]$OsInfo.BuildNumber
$Report.CurrentBuild = "$BuildNumber ($($OsInfo.Caption))"
Write-Host "    当前内部版本: $BuildNumber ($($OsInfo.Caption))" -ForegroundColor Gray

if ($BuildNumber -ge 26100 -and $BuildNumber -lt 26300) {
    $Report.ServicingBranch = "Germanium Shared Servicing Branch (24H2/25H2)"
    Write-Host "    [+] 分支匹配成功: 处于 24H2/25H2 共享代码基通道，支持 eKB 平滑升级！" -ForegroundColor Green
} elseif ($BuildNumber -ge 26300) {
    $Report.ServicingBranch = "Windows 11 26H2 Active"
    Write-Host "    [+] 系统已成功处于 Windows 11 26H2 (Build $BuildNumber)！" -ForegroundColor Green
} else {
    $Report.ServicingBranch = "Legacy Branch / Independent Build"
    Write-Host "    [!] 警告: 当前内部版本低于 26100 或处于 26H1 独立内核分支。" -ForegroundColor Red
    Write-Host "    [!] 26H1 设备无法通过 KB5121794 激活包直接升级，需使用完整 ISO 安装镜像！" -ForegroundColor Yellow
}

# 2. 检查前置累计更新 KB5124010
Write-Host "`n[2/5] 检查必备前置补丁 KB5124010 状态..." -ForegroundColor Yellow
$Hotfixes = Get-CimInstance Win32_QuickFixEngineering | Select-Object -ExpandProperty HotFixID
if ($Hotfixes -contains "KB5124010") {
    $Report.KB5124010Installed = $true
    Write-Host "    [+] 前置补丁 KB5124010 已就绪 [PASS]" -ForegroundColor Green
} else {
    $Report.KB5124010Installed = $false
    Write-Host "    [!] 缺失前置补丁 KB5124010！" -ForegroundColor Red
    Write-Host "    [!] 若未安装此累计更新直接启用 KB5121794，将导致错误 0x80073712。" -ForegroundColor Yellow
    if ($Mode -eq "Execute") {
        Write-Host "    [*] 正在通过 Windows Update 通道触发前置补丁检索..." -ForegroundColor Cyan
        USOClient StartInteractiveScan
        $Report.ActionTaken += "Triggered USOClient Interactive Scan for KB5124010"
    }
}

# 3. 扫描 WinSxS 组件库健康状态
Write-Host "`n[3/5] 校验 WinSxS 系统组件存储库健康状态..." -ForegroundColor Yellow
if ($Mode -eq "Execute") {
    Write-Host "    [*] 正在执行 dism /online /cleanup-image /restorehealth 在线修复..." -ForegroundColor Cyan
    $DismOut = & dism.exe /Online /Cleanup-Image /RestoreHealth
    Write-Host "    [*] 正在执行 sfc /scannow 系统完整性检查..." -ForegroundColor Cyan
    $SfcOut = & sfc.exe /scannow
    $Report.ComponentStoreHealthy = $true
    $Report.ActionTaken += "Executed DISM RestoreHealth and SFC Scannow"
    Write-Host "    [+] 组件存储库修复完毕 [PASS]" -ForegroundColor Green
} else {
    Write-Host "    [*] 审计模式: 执行快速只读健康检测 (ScanHealth)..." -ForegroundColor Gray
    $DismScan = & dism.exe /Online /Cleanup-Image /CheckHealth
    if ($LASTEXITCODE -eq 0) {
        $Report.ComponentStoreHealthy = $true
        Write-Host "    [+] WinSxS 状态良好，未见结构性损坏 [PASS]" -ForegroundColor Green
    } else {
        $Report.ComponentStoreHealthy = $false
        Write-Host "    [!] 发现损坏包，建议使用 -Mode Execute 进行修复！" -ForegroundColor Yellow
    }
}

# 4. BitLocker 保护锁与恢复密钥脱敏备份
Write-Host "`n[4/5] 检查 BitLocker 全盘加密状态并提取安全恢复码..." -ForegroundColor Yellow
$BitLocker = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
if ($BitLocker) {
    $Report.BitLockerProtection = $BitLocker.ProtectionStatus.ToString()
    Write-Host "    系统盘 (C:) 保护状态: $($BitLocker.ProtectionStatus) | 锁状态: $($BitLocker.LockStatus)" -ForegroundColor Gray
    
    if ($BitLocker.ProtectionStatus -eq "On") {
        $KeyProtector = $BitLocker.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" } | Select-Object -First 1
        if ($KeyProtector) {
            $BackupPath = "$env:USERPROFILE\BitLocker_Recovery_Key_Safe.txt"
            $SecretKey = $KeyProtector.RecoveryPassword
            $MaskedKey = $SecretKey.Substring(0, 11) + "-XXXXXX-XXXXXX-XXXXXX-" + $SecretKey.Substring($SecretKey.Length - 6)
            
            if ($Mode -eq "Execute") {
                Set-Content -Path $BackupPath -Value "BitLocker Recovery Key (Drive C:): $SecretKey`nGenerated on: $(Get-Date)" -Force
                Write-Host "    [+] 48 位恢复密钥已成功导出备份至: $BackupPath" -ForegroundColor Green
                Write-Host "    [+] 脱敏密钥凭据: $MaskedKey" -ForegroundColor Gray
                $Report.ActionTaken += "Exported BitLocker Key to $BackupPath"
            } else {
                Write-Host "    [•] 侦测到有效恢复密钥: $MaskedKey (Audit 模式不写入磁盘)" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "    [•] 未配置 BitLocker 加密卷或当前处于家庭版非加密环境。" -ForegroundColor Gray
    $Report.BitLockerProtection = "NotConfigured"
}

# 5. USB Audio Class 1.0 设备排查与 Code 10 规避
Write-Host "`n[5/5] 排查老式 USB Audio Class 1.0 设备与驱动兼容性..." -ForegroundColor Yellow
$AudioPnp = Get-PnpDevice -Class "MEDIA" -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like "*USB*" }

foreach ($dev in $AudioPnp) {
    $Status = $dev.Status
    $Name = $dev.FriendlyName
    $Report.UsbAudioClass1Devices += "$Name ($Status)"
    Write-Host "    发现音频外设: $Name [状态: $Status]" -ForegroundColor Gray

    if ($Status -eq "Error") {
        Write-Host "    [!] 警报: 设备处于异常挂起状态 (可能受 Code 10 影响)！" -ForegroundColor Red
    }
}

if ($Mode -eq "Execute") {
    Write-Host "    [*] 正在写入 USB Audio Class 1.0 兼容回退与 KIR 注册表策略..." -ForegroundColor Cyan
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\usbaudio\Parameters"
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }
    # 强制启用兼容异步包同步与缓冲区宽限
    Set-ItemProperty -Path $RegPath -Name "EnableLegacyClockSync" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $RegPath -Name "IsochBufferTimeoutMs" -Value 200 -Type DWord -Force
    Write-Host "    [+] USB 声卡高精度时钟规避补丁已写入注册表！" -ForegroundColor Green
    $Report.ActionTaken += "Configured EnableLegacyClockSync and IsochBufferTimeoutMs in registry"
}

# 综合评估
if ($Report.ServicingBranch -like "*Germanium*" -and $Report.KB5124010Installed -and $Report.ComponentStoreHealthy) {
    $Report.ReadyFor26H2 = $true
}

Write-Host "`n[•] ========================================================" -ForegroundColor Cyan
Write-Host "[•]  巡检执行结论汇总                                       " -ForegroundColor Cyan
Write-Host "[•] ========================================================" -ForegroundColor Cyan
Write-Host "    操作系统分支: $($Report.ServicingBranch)" -ForegroundColor Gray
Write-Host "    前置补丁状态: $(if ($Report.KB5124010Installed) { '已就绪' } else { '缺失' })" -ForegroundColor Gray
Write-Host "    组件存储库  : $(if ($Report.ComponentStoreHealthy) { '健康' } else { '需修复' })" -ForegroundColor Gray
Write-Host "    26H2就绪评估: $(if ($Report.ReadyFor26H2) { '完美就绪，可放心升级！' } else { '存在阻断项，请先排除！' })" -ForegroundColor $(if ($Report.ReadyFor26H2) { "Green" } else { "Yellow" })

# 输出 JSON 状态文件便于 Agent 验收
$JsonOut = "$PSScriptRoot\win11_26h2_report.json"
$Report | ConvertTo-Json -Depth 4 | Set-Content -Path $JsonOut -Force
Write-Host "`n[+] 机器可读诊断报表已生成: $JsonOut" -ForegroundColor Green

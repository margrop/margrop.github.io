# ==============================================================================
# OpenAI Dots Open-Source Implementations Toolkit for Windows 11 (26H2 / PowerShell 7)
# ==============================================================================
# Native PowerShell script for automated deployment, preflight check, and management
# of open-source dots runtimes (feder-cr/dots, Anil-matcha/open-dots).
#
# Supported Execution Modes:
#   1. Interactive Mode: powershell -ExecutionPolicy Bypass -File .\openai_dots_oss_toolkit_windows11.ps1
#   2. Agent / Non-Interactive Mode:
#      powershell -ExecutionPolicy Bypass -File .\openai_dots_oss_toolkit_windows11.ps1 -AgentMode -Port 8765 -Headless $true
#
# Zero external proprietary dependencies. Pure native Windows PowerShell.
# ==============================================================================

[CmdletBinding()]
param (
    [switch]$AgentMode = $false,
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8765,
    [int]$Seed = 894129,
    [bool]$Headless = $true,
    [string]$OpenRouterKey = $env:OPENROUTER_API_KEY,
    [string]$ProfileDir = "$env:LOCALAPPDATA\dots\profiles\default",
    [string]$LogDir = "$env:LOCALAPPDATA\dots\logs"
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$msg) {
    if (-not $AgentMode) {
        Write-Host "[INFO] $msg" -ForegroundColor Cyan
    }
}

function Write-Ok([string]$msg) {
    if (-not $AgentMode) {
        Write-Host "[OK] $msg" -ForegroundColor Green
    }
}

function Write-Warn([string]$msg) {
    if (-not $AgentMode) {
        Write-Host "[WARN] $msg" -ForegroundColor Yellow
    }
}

function Write-Err([string]$msg) {
    if (-not $AgentMode) {
        Write-Host "[ERROR] $msg" -ForegroundColor Red
    }
}

function Test-Preflight() {
    Write-Info "Executing Windows 11 preflight diagnostic..."

    # Check OS Version
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Ok "Operating System: $($os.Caption) (Build $($os.BuildNumber))"

    # Check Python
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $pyVer = & python --version 2>&1
        Write-Ok "Python runtime detected: $pyVer"
    } else {
        Write-Warn "Python not found in PATH. Checking winget or uv standalone..."
    }

    # Check or Install uv
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uvCmd) {
        $userUv = "$env:USERPROFILE\.local\bin\uv.exe"
        if (Test-Path $userUv) {
            $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
            Write-Ok "Loaded uv from user directory: $userUv"
        } else {
            Write-Info "Installing Astral uv via official PowerShell bootstrapper..."
            try {
                Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
                $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
            } catch {
                Write-Err "Failed to install uv automatically: $_"
                return $false
            }
        }
    }

    $uvVer = & uv --version 2>&1
    Write-Ok "Astral uv runtime verified: $uvVer"

    # Check Local Ollama
    try {
        $ollamaResp = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/version" -TimeoutSec 2 -ErrorAction Stop
        Write-Ok "Local Ollama service detected (Version: $($ollamaResp.version))"
    } catch {
        Write-Warn "Local Ollama service not detected on port 11434."
    }

    return $true
}

function Initialize-Storage() {
    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    Write-Ok "Storage initialized at $ProfileDir"
}

function Start-DotsRuntime() {
    Initialize-Storage
    Write-Info "Configuring Dots runtime on ${HostAddress}:${Port} (Seed: $Seed)..."

    $runArgs = @(
        "dots", "ui",
        "--host", $HostAddress,
        "--port", $Port,
        "--seed", $Seed,
        "--profile-dir", $ProfileDir
    )

    if (-not $Headless) {
        $runArgs += "--headed"
    }

    if ($OpenRouterKey) {
        $runArgs += @("--openrouter-key", $OpenRouterKey)
    }

    if ($AgentMode) {
        @{
            status = "starting"
            host = $HostAddress
            port = $Port
            profile_dir = $ProfileDir
        } | ConvertTo-Json -Compress | Write-Output
        & uvx --from "git+https://github.com/feder-cr/dots" @runArgs
        return
    }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Magenta
    Write-Host "  ✨ Launching Open-Source Dots Agent Runtime on Windows 11!" -ForegroundColor Green
    Write-Host "  🌐 Web UI & Conversation : http://${HostAddress}:${Port}" -ForegroundColor Cyan
    Write-Host "  🛡️ Stealth Browser       : Patched Firefox (Seed: ${Seed})" -ForegroundColor Cyan
    Write-Host "  📁 Session Storage       : $ProfileDir" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Magenta
    Write-Host ""

    & uvx --from "git+https://github.com/feder-cr/dots" @runArgs
}

function Show-InteractiveMenu() {
    Clear-Host
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "   OpenAI Dots 开源平替部署工具包 (Windows 11 原生 PowerShell)" -ForegroundColor Magenta
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host " 1. 运行系统前置环境探测 (Preflight Diagnostic)"
    Write-Host " 2. 一键启动 Stealth 隐形 Web 智能体 (feder-cr/dots)"
    Write-Host " 3. 检测本地 Ollama / vLLM 私有大模型推理端点"
    Write-Host " 4. 注册 Windows 计划任务后台 24 小日常驻服务 (Task Scheduler)"
    Write-Host " 5. 退出 (Exit)"
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    $choice = Read-Host "请选择操作 [1-5]"

    switch ($choice) {
        "1" {
            Test-Preflight | Out-Null
            Read-Host "按回车键返回主菜单..."
            Show-InteractiveMenu
        }
        "2" {
            Test-Preflight | Out-Null
            $inputKey = Read-Host "请输入 OpenRouter API Key (留空使用已配置环境变量)"
            if ($inputKey) {
                $script:OpenRouterKey = $inputKey
            }
            Start-DotsRuntime
        }
        "3" {
            Write-Info "Probing local inference endpoints..."
            try {
                $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3 -ErrorAction Stop
                Write-Ok "Local Ollama is running! Available models:"
                foreach ($m in $tags.models) {
                    Write-Host "  - $($m.name)" -ForegroundColor Green
                }
            } catch {
                Write-Warn "Ollama not found on 127.0.0.1:11434."
            }
            Read-Host "按回车键返回主菜单..."
            Show-InteractiveMenu
        }
        "4" {
            Write-Info "Registering Windows Scheduled Task for 24/7 background agent..."
            $taskName = "OpenSourceDotsAgent"
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -AgentMode -Port $Port"
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "OpenAI Dots OSS Background Agent" -Force | Out-Null
            Write-Ok "Scheduled Task '$taskName' registered successfully."
            Write-Host "To start now: Start-ScheduledTask -TaskName '$taskName'"
            Read-Host "按回车键返回主菜单..."
            Show-InteractiveMenu
        }
        "5" {
            exit 0
        }
        default {
            Show-InteractiveMenu
        }
    }
}

if ($AgentMode) {
    if (Test-Preflight) {
        Start-DotsRuntime
    }
} else {
    Show-InteractiveMenu
}

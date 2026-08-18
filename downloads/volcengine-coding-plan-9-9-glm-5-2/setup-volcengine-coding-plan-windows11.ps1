param([string]$ApiKey,[string]$Model="glm-5.2")
$ErrorActionPreference="Stop"
if (-not $ApiKey) { $ApiKey = Read-Host "请输入方舟 Coding Plan API Key" }
if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw "API Key 不能为空" }
[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL","https://ark.cn-beijing.volces.com/api/coding","User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN",$ApiKey,"User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_MODEL",$Model,"User")
Write-Host "配置完成。请重新打开 Windows Terminal，再启动 Claude Code。"

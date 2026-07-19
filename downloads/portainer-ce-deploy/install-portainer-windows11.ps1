[CmdletBinding()]
param(
    [string]$Version = "2.39.4",
    [string]$ContainerName = "portainer",
    [string]$VolumeName = "portainer_data",
    [switch]$EnableLegacyHttp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker Desktop is required. Install and start Docker Desktop, then rerun this script."
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is installed but its Docker engine is not running."
}

docker container inspect $ContainerName *> $null
if ($LASTEXITCODE -eq 0) {
    $running = docker inspect -f "{{.State.Running}}" $ContainerName
    $image = docker inspect -f "{{.Config.Image}}" $ContainerName
    if ($running -ne "true") {
        docker start $ContainerName | Out-Null
    }
    Write-Host "Container $ContainerName already exists and is using $image."
    Write-Host "Open https://localhost:9443"
    exit 0
}

docker volume inspect $VolumeName *> $null
if ($LASTEXITCODE -ne 0) {
    docker volume create $VolumeName | Out-Null
}

$image = "portainer/portainer-ce:$Version"
docker pull $image
if ($LASTEXITCODE -ne 0) {
    throw "Unable to pull $image."
}

$runArgs = @(
    "run", "-d",
    "-p", "9443:9443",
    "--name", $ContainerName,
    "--restart=always",
    "-v", "/var/run/docker.sock:/var/run/docker.sock",
    "-v", "${VolumeName}:/data"
)
if ($EnableLegacyHttp) {
    $runArgs += @("-p", "9000:9000")
}
$runArgs += $image

& docker @runArgs | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker could not create the Portainer container."
}

for ($attempt = 1; $attempt -le 30; $attempt++) {
    $runningName = docker ps --filter "name=^/$ContainerName$" --filter "status=running" --format "{{.Names}}"
    if ($runningName -eq $ContainerName) {
        Write-Host "Portainer $Version is running."
        Write-Host "Open https://localhost:9443"
        if ($EnableLegacyHttp) {
            Write-Host "Legacy HTTP is also available at http://localhost:9000"
        }
        exit 0
    }
    Start-Sleep -Seconds 1
}

docker logs --tail 80 $ContainerName
throw "Portainer did not reach the running state within 30 seconds."

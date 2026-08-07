param(
  [string]$QingLongData = ".\qinglong-data",
  [string]$BaiHuData = ".\baihu-data",
  [string]$BaiHuContainer = "baihu"
)

$ErrorActionPreference = "Stop"
$image = docker inspect $BaiHuContainer --format "{{.Config.Image}}"
if (-not $image) { throw "Cannot inspect BaiHu container image." }

docker stop $BaiHuContainer | Out-Null
try {
  docker run --rm `
    -v "${PWD}\ql2bh-migrate.py:/work/ql2bh-migrate.py:ro" `
    -v "${QingLongData}:/tmp/ql2bh-migration-lab/qinglong-data:ro" `
    -v "${BaiHuData}:/tmp/ql2bh-migration-lab/baihu-data" `
    -v "\\.\pipe\docker_engine:\\.\pipe\docker_engine" `
    $image python /work/ql2bh-migrate.py
}
finally {
  docker start $BaiHuContainer | Out-Null
}

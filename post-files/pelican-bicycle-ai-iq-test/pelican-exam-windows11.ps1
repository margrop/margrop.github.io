# pelican-exam-windows11.ps1
# 鹈鹕骑车测试 · 离线阅卷器 (Windows 11 原生 PowerShell 版, 零依赖)
# 用法: .\pelican-exam-windows11.ps1 my-answer.svg   (无参数则生成答题模板)

param([string]$Path = "")
$ErrorActionPreference = "Stop"

function Parse-Num([string]$v, [double]$dft) {
    $n = 0.0
    if ([double]::TryParse($v, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
    return $dft
}

if (-not $Path) {
    $tpl = @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500" width="800" height="500">
  <!-- 把任何聊天 AI 给你的 SVG 答案粘贴到这里替换本文件内容, 然后重新运行本脚本 -->
</svg>
'@
    Set-Content -Path "my-answer.svg" -Value $tpl -Encoding UTF8
    Write-Host "已生成答题模板 my-answer.svg"
    Write-Host "把 AI 给你的 SVG 代码粘贴进去保存, 再运行: .\pelican-exam-windows11.ps1 my-answer.svg"
    exit 0
}

$rows = New-Object System.Collections.ArrayList
function Add-Check([bool]$Ok, [int]$Pts, [string]$Label, [string]$Detail = "") {
    $null = $script:rows.Add(@{ Ok = $Ok; Pts = $Pts; Label = $Label; Detail = $Detail })
    if ($Ok) { return $Pts } else { return 0 }
}

try {
    [xml]$xml = Get-Content -Path $Path -Raw -Encoding UTF8
} catch {
    Write-Host "XML 语法无法解析, 直接 0 分: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$total = 0
$root = $xml.DocumentElement

# 1) 根元素与命名空间 (10)
$nsOk = ($root.LocalName -eq "svg") -and ($root.NamespaceURI -eq "http://www.w3.org/2000/svg")
$total += Add-Check $nsOk 10 "根元素是 <svg> 且声明 xmlns" $(if (-not $nsOk) { "缺 xmlns 时浏览器会拒绝渲染" })

# 2) viewBox (10)
$vb = $root.GetAttribute("viewBox")
$total += Add-Check ([bool]$vb) 10 "声明了 viewBox" $(if (-not $vb) { "缩放行为不可控" })

$all = $xml.SelectNodes("//*")
$circles = @(); $ellipses = @(); $nlines = 0; $npaths = 0
$fills = @(); $anim = 0
foreach ($el in $all) {
    switch ($el.LocalName) {
        "circle" {
            $r = Parse-Num $el.GetAttribute("r") 0
            if ($r -gt 0) {
                $circles += @{ CX = Parse-Num $el.GetAttribute("cx") 0; CY = Parse-Num $el.GetAttribute("cy") 0; R = $r }
            }
        }
        "ellipse" { $ellipses += @{ CX = Parse-Num $el.GetAttribute("cx") 0; CY = Parse-Num $el.GetAttribute("cy") 0; RX = Parse-Num $el.GetAttribute("rx") 0; RY = Parse-Num $el.GetAttribute("ry") 0 } }
        "line" { $nlines++ }
        "path" { $npaths++ }
        default {}
    }
    if ($el.LocalName -like "animate*") { $anim++ }
    foreach ($k in @("fill", "stroke")) {
        $v = $el.GetAttribute($k)
        if ($v) { $fills += $v.ToLower() }
    }
}

# 3) 车轮: 同心圆去重后恰好两个大圆 (15)
$minDim = 400.0
if ($vb) { $p = $vb -split "[ ,]+"; $minDim = [Math]::Min((Parse-Num $p[2] 400), (Parse-Num $p[3] 400)) }
$kept = @()
foreach ($c in $circles) {
    $dup = $false
    for ($i = 0; $i -lt $kept.Count; $i++) {
        $k = $kept[$i]
        if ([Math]::Sqrt([Math]::Pow($c.CX - $k.CX, 2) + [Math]::Pow($c.CY - $k.CY, 2)) -le 0.25 * [Math]::Max($c.R, $k.R)) {
            if ($c.R -gt $k.R) { $kept[$i] = $c }
            $dup = $true; break
        }
    }
    if (-not $dup) { $kept += $c }
}
$big = @($kept | Where-Object { $_.R -ge 0.10 * $minDim })
$wheelsOk = ($big.Count -eq 2)
$total += Add-Check $wheelsOk 15 "恰好两个「车轮级」大圆" $(if (-not $wheelsOk) { "实际找到 $($big.Count) 个" })

if ($wheelsOk) {
    $r1 = $big[0].R; $r2 = $big[1].R
    $rr = [Math]::Abs($r1 - $r2) / [Math]::Max($r1, $r2)
    $total += Add-Check ($rr -le 0.10) 10 "前后轮半径一致 (±10%)" $(if ($rr -gt 0.10) { "差了 $([math]::Round($rr*100))%" })
    $b1 = $big[0].CY + $r1; $b2 = $big[1].CY + $r2
    $br = [Math]::Abs($b1 - $b2) / [Math]::Max($r1, $r2)
    $total += Add-Check ($br -le 0.15) 10 "两轮底边同一水平线 (±15%R)" $(if ($br -gt 0.15) { "一个轮子离地 $([math]::Round($br*100))%R" })
    $cxMin = [Math]::Min($big[0].CX, $big[1].CX) - [Math]::Max($r1, $r2)
    $cxMax = [Math]::Max($big[0].CX, $big[1].CX) + [Math]::Max($r1, $r2)
    $bodyTop = [Math]::Min($b1, $b2) - 3 * [Math]::Max($r1, $r2)
    $hasBody = $false
    foreach ($e in $ellipses) {
        if ($e.CX -ge $cxMin -and $e.CX -le $cxMax -and $e.CY -lt ($bodyTop + 2 * [Math]::Max($r1, $r2))) { $hasBody = $true }
    }
    foreach ($c in $kept) {
        if (-not ($big -contains $c) -and $c.R -ge 0.12 * $minDim -and $c.CX -ge $cxMin -and $c.CX -le $cxMax -and $c.CY -lt ($bodyTop + 2 * [Math]::Max($r1, $r2))) { $hasBody = $true }
    }
    $total += Add-Check $hasBody 10 "两轮之间上方有「鸟身」" $(if (-not $hasBody) { "只有车没有鸟, 或鸟飘在画面外" })
} else {
    $total += Add-Check $false 0 "前后轮半径一致 (±10%)" "轮子数量都不对, 跳过"
    $total += Add-Check $false 0 "两轮底边同一水平线" ""
    $total += Add-Check $false 0 "两轮之间上方有「鸟身」" ""
}

# 7) 橙色喙 (10)
$orangeWords = @("orange", "#f5a623", "#ffa500", "#ffd700", "#f39c12", "#e67e22", "#f8bd5a", "#ff8c00")
$beakOk = $false
foreach ($f in $fills) { foreach ($w in $orangeWords) { if ($f.Contains($w)) { $beakOk = $true } } }
$total += Add-Check $beakOk 10 "存在橙色系「喙」" $(if (-not $beakOk) { "找不到橙/黄色喙, 鹈鹕变麻雀" })

# 8) 线条骨架 (10)
$total += Add-Check (($nlines + $npaths) -ge 1) 10 "存在线/路径元素 (腿、车架)" $(if (($nlines + $npaths) -lt 1) { "全是色块拼贴, 没有线条骨架" })

# 9) 构图面积 (15)
$coverOk = ((Get-Item $Path).Length -gt 300)
$coverTxt = "画了个寂寞"
if ($vb) {
    $xs = @(); $ys = @()
    foreach ($c in $circles) { $xs += ($c.CX - $c.R); $xs += ($c.CX + $c.R); $ys += ($c.CY - $c.R); $ys += ($c.CY + $c.R) }
    foreach ($e in $ellipses) { $xs += ($e.CX - $e.RX); $xs += ($e.CX + $e.RX); $ys += ($e.CY - $e.RY); $ys += ($e.CY + $e.RY) }
    if ($xs.Count -gt 0) {
        $p = $vb -split "[ ,]+"
        $cover = (($xs | Measure-Object -Maximum).Maximum - ($xs | Measure-Object -Minimum).Minimum) * (($ys | Measure-Object -Maximum).Maximum - ($ys | Measure-Object -Minimum).Minimum) / ((Parse-Num $p[2] 400) * (Parse-Num $p[3] 400))
        $coverOk = ($cover -ge 0.20)
        $coverTxt = "只占了 $([math]::Round($cover*100))%"
    }
}
$total += Add-Check $coverOk 15 "构图占画面 ≥20%" $(if (-not $coverOk) { $coverTxt })

$animPts = 0
if ($anim -gt 0) { $animPts = 20 }
$rawText = Get-Content -Path $Path -Raw -Encoding UTF8
if ($rawText -match "@keyframes") { $animPts = 20 }

Write-Host ""
Write-Host "🦩 鹈鹕骑车测试 · 阅卷报告: $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
foreach ($r in $rows) {
    if ($r.Ok) { $color = "Green" } else { $color = "Red" }
    $line = "  {0} [{1,3}分] {2}" -f $(if ($r.Ok) { "✅" } else { "❌" }), $r.Pts, $r.Label
    if ($r.Detail) { $line += "  -- $($r.Detail)" }
    Write-Host $line -ForegroundColor $color
}
$animNote = ""
if ($animPts -gt 0) { $animNote = " (含动画加分 +20)" }
Write-Host "  总分: $total/100$animNote" -ForegroundColor Yellow
$verdict = if ($total -ge 85) { "车是车, 鸟是鸟, 骑在一起也合理, 高分!" } elseif ($total -ge 60) { "能看出在画什么, 但细节全是破绽。" } elseif ($total -ge 30) { "抽象派大作, 人类考官陷入沉思。" } else { "这不是鹈鹕, 这是灾难现场。" }
Write-Host "  一句话点评: $verdict"

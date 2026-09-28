# ==============================================================================
# Pantum P2206W AirPrint 825-Day Certificate Auto-Fix Toolkit (Windows 11)
# Zero external dependencies. Uses PowerShell 7+ and native OpenSSL / CertUtil.
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PrinterHost = "",

    [Parameter(Mandatory=$false)]
    [int]$ValidityDays = 825,

    [Parameter(Mandatory=$false)]
    [string]$Password = "123456",

    [Parameter(Mandatory=$false)]
    [switch]$Auto
)

$ErrorActionPreference = "Stop"

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " 🖨️  Pantum P2206W × iOS 27 AirPrint Toolkit (Windows 11)" -ForegroundColor Green
Write-Host " 🛡️  Enforcing Apple ATS 825-Day Certificate Lifespan & SAN Rules" -ForegroundColor Yellow
Write-Host "========================================================================" -ForegroundColor Cyan

# 1. Check OpenSSL availability
$OpenSsl = Get-Command "openssl" -ErrorAction SilentlyContinue
if (-not $OpenSsl) {
    Write-Warning "OpenSSL is not found in PATH. Checking Git OpenSSL..."
    $GitOpenSsl = "C:\Program Files\Git\usr\bin\openssl.exe"
    if (Test-Path $GitOpenSsl) {
        $OpenSslPath = $GitOpenSsl
    } else {
        Write-Error "OpenSSL is required. Please install OpenSSL or Git for Windows, then retry."
    }
} else {
    $OpenSslPath = "openssl"
}

# 2. Output directory
$BuildDir = Join-Path $PSScriptRoot "build"
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

$KeyFile = Join-Path $BuildDir "pantum_p2206w.key"
$CrtFile = Join-Path $BuildDir "pantum_p2206w.crt"
$PfxFile = Join-Path $BuildDir "pantum_p2206w_825d.pfx"

# 3. Generate 825-day certificate
Write-Host "[*] Generating $ValidityDays-day self-signed certificate with SAN..." -ForegroundColor Cyan
$Subject = "/C=CN/O=Local Printer/CN=printer.local"
$SanExt = "subjectAltName=DNS:printer.local,DNS:Pantum-XXXXXX.local,IP:127.0.0.1"

& $OpenSslPath req -x509 -nodes -newkey rsa:2048 -days $ValidityDays `
    -keyout $KeyFile -out $CrtFile `
    -subj $Subject `
    -addext $SanExt

# 4. Package into PKCS#12 (.pfx)
Write-Host "[*] Packaging into PKCS#12 (.pfx) container..." -ForegroundColor Cyan
& $OpenSslPath pkcs12 -export -out $PfxFile `
    -inkey $KeyFile -in $CrtFile `
    -passout "pass:$Password"

$PfxSize = (Get-Item $PfxFile).Length
Write-Host "[+] Generated '$PfxFile' ($PfxSize bytes, limit: 51200 bytes)." -ForegroundColor Green

if ($PrinterHost -ne "") {
    Write-Host "[*] Uploading to Pantum printer at http://$PrinterHost/docertificate ..." -ForegroundColor Cyan
    $Uri = "http://$PrinterHost/docertificate"
    $Boundary = [System.Guid]::NewGuid().ToString()

    $LF = "`r`n"
    $Body = (
        "--$Boundary$LF" +
        "Content-Disposition: form-data; name=`"sslcertkey`"$LF$LF" +
        "$Password$LF" +
        "--$Boundary$LF" +
        "Content-Disposition: form-data; name=`"input_file_upload`"; filename=`"pantum_p2206w_825d.pfx`"$LF" +
        "Content-Type: application/x-pkcs12$LF$LF"
    )

    $PfxBytes = [System.IO.File]::ReadAllBytes($PfxFile)
    $HeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $FooterBytes = [System.Text.Encoding]::UTF8.GetBytes("$LF--$Boundary--$LF")

    $FullBytes = [byte[]]::new($HeaderBytes.Length + $PfxBytes.Length + $FooterBytes.Length)
    [System.Buffer]::BlockCopy($HeaderBytes, 0, $FullBytes, 0, $HeaderBytes.Length)
    [System.Buffer]::BlockCopy($PfxBytes, 0, $FullBytes, $HeaderBytes.Length, $PfxBytes.Length)
    [System.Buffer]::BlockCopy($FooterBytes, 0, $FullBytes, $HeaderBytes.Length + $PfxBytes.Length, $FooterBytes.Length)

    Invoke-RestMethod -Uri $Uri -Method Post -ContentType "multipart/form-data; boundary=$Boundary" -Body $FullBytes
    Write-Host "[✓] Upload successful! The printer is reloading its SSL/TLS configuration." -ForegroundColor Green
} else {
    Write-Host "[*] Manual Action Required:" -ForegroundColor Yellow
    Write-Host "    1. Open printer web backend: http://<printer-ip>/index-jump.html" -ForegroundColor Yellow
    Write-Host "    2. Go to: Settings -> Protocol Settings -> SSL/TLS" -ForegroundColor Yellow
    Write-Host "    3. Enter Private Key password: $Password" -ForegroundColor Yellow
    Write-Host "    4. Choose File: '$PfxFile' and click 'Certificate Installation'" -ForegroundColor Yellow
}

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host " [✓] Windows 11 Pantum Toolkit Execution Completed Successfully!" -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Cyan

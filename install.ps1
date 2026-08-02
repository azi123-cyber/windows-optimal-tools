# Windows All-in-One Utility - Web Installer / Loader Script
# Cara menggunakan (ubah USERNAME_KAMU dengan username GitHub Anda setelah di-upload):
# iwr -useb https://raw.githubusercontent.com/USERNAME_KAMU/WIN11OPT/main/install.ps1 | iex

$repoOwner = "YOUR_GITHUB_USERNAME" # GANTI DENGAN USERNAME GITHUB ANDA
$repoName = "WIN11OPT"
$branch = "main"

$baseUrl = "https://raw.githubusercontent.com/$repoOwner/$repoName/$branch"
$installDir = "$env:SystemDrive\Win11Opt"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   WINDOW ALL-IN-ONE UTILITY WEB LOADER" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Pastikan dijalankan sebagai Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Script membutuhkan hak Administrator. Meluncurkan ulang sebagai Administrator..." -ForegroundColor Yellow
    # Relaunch installer script as Administrator
    $loaderCommand = "iwr -useb $baseUrl/install.ps1 | iex"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $loaderCommand`"" -Verb RunAs
    Exit
}

# 2. Buat struktur folder instalasi lokal
Write-Host "Membuat direktori kerja di $installDir..." -ForegroundColor Gray
try {
    if (!(Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
    if (!(Test-Path "$installDir\ui")) { New-Item -ItemType Directory -Path "$installDir\ui" -Force | Out-Null }
    if (!(Test-Path "$installDir\modules")) { New-Item -ItemType Directory -Path "$installDir\modules" -Force | Out-Null }
}
catch {
    Write-Error "Gagal membuat direktori instalasi: $_"
    Exit
}

# 3. Daftar aset file yang akan diunduh dari repository
$files = @(
    @{ Src = "src/Win11Opt.ps1"; Dest = "Win11Opt.ps1" },
    @{ Src = "src/ui/MainView.xaml"; Dest = "ui/MainView.xaml" },
    @{ Src = "src/modules/Optimizer.psm1"; Dest = "modules/Optimizer.psm1" },
    @{ Src = "src/modules/DisplayFix.psm1"; Dest = "modules/DisplayFix.psm1" },
    @{ Src = "src/modules/Security.psm1"; Dest = "modules/Security.psm1" },
    @{ Src = "src/modules/Bloatware.psm1"; Dest = "modules/Bloatware.psm1" },
    @{ Src = "src/modules/Activation.psm1"; Dest = "modules/Activation.psm1" }
)

# 4. Unduh aset file menggunakan WebRequest / WebClient
Write-Host "Mengunduh aset-aset aplikasi..." -ForegroundColor Gray
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$webClient = New-Object System.Net.WebClient

foreach ($file in $files) {
    $downloadUrl = "$baseUrl/$($file.Src)"
    $destination = "$installDir/$($file.Dest)"
    Write-Host "Mengunduh: $($file.Dest)..." -ForegroundColor Gray
    try {
        $webClient.DownloadFile($downloadUrl, $destination)
    }
    catch {
        Write-Error "Gagal mengunduh file dari $downloadUrl ke $destination: $_"
        Write-Host "Tips: Pastikan nama repository dan username GitHub Anda di baris awal script ini sudah benar." -ForegroundColor Yellow
        Exit
    }
}

Write-Host "Instalasi selesai dengan sukses!" -ForegroundColor Green
Write-Host "Menjalankan aplikasi utama..." -ForegroundColor Green
Start-Sleep -Seconds 1

# 5. Jalankan aplikasi dalam mode STA
Start-Process powershell.exe -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$installDir\Win11Opt.ps1`""

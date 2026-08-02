# Windows All-in-One Utility - Compilation Script
# Script ini digunakan untuk mengkompilasi file .ps1 utama menjadi file .exe mandiri menggunakan PS2EXE.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceFile = Resolve-Path "$scriptDir/../src/Win11Opt.ps1" -ErrorAction SilentlyContinue
$outputFile = "$scriptDir/../build/Win11Opt.exe"

if (-not $sourceFile) {
    Write-Error "File source utama tidak ditemukan di: src/Win11Opt.ps1"
    Exit
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  MENGKOMPILASI WINDOWS AIO UTILITY KE EXE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Pastikan modul PS2EXE terinstal di Windows host
Write-Host "Memeriksa modul ps2exe..." -ForegroundColor Gray
if (-not (Get-Module -ListAvailable ps2exe)) {
    Write-Host "Modul ps2exe tidak ditemukan. Menginstal ps2exe..." -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-Module -Name ps2exe -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
        Write-Host "ps2exe berhasil diinstal!" -ForegroundColor Green
    }
    catch {
        Write-Error "Gagal menginstal ps2exe: $_. Pastikan koneksi internet terhubung atau jalankan 'Install-Module ps2exe' secara manual."
        Exit
    }
}

# 2. Jalankan kompilasi menggunakan Invoke-PS2EXE
Write-Host "Menjalankan kompilasi script utama..." -ForegroundColor Gray
try {
    # Parameter:
    # -noConsole: Menghindari munculnya jendela CMD hitam di belakang GUI WPF.
    Invoke-PS2EXE -inputFile $sourceFile -outputFile $outputFile `
                  -noConsole `
                  -title "Windows All-in-One Utility" `
                  -description "Windows 10/11 system optimizer, display repair, Windows activation and bloatware clean tool." `
                  -company "Win11Opt Open Source Project" `
                  -version "1.0.0.0" `
                  -ErrorAction Stop
                  
    Write-Host "Kompilasi file .exe berhasil dibuat di: build/Win11Opt.exe" -ForegroundColor Green
}
catch {
    Write-Error "Gagal melakukan kompilasi script: $_"
    Exit
}

# 3. Salin resource ui/ dan modules/ agar exe dapat berjalan mandiri
Write-Host "Menyalin modul dan XAML UI pendukung..." -ForegroundColor Gray
try {
    $buildDir = "$scriptDir/../build"
    
    # Hapus folder lama agar bersih
    if (Test-Path "$buildDir/ui") { Remove-Item -Path "$buildDir/ui" -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path "$buildDir/modules") { Remove-Item -Path "$buildDir/modules" -Recurse -Force -ErrorAction SilentlyContinue }
    
    # Buat direktori baru
    New-Item -ItemType Directory -Path "$buildDir/ui" -Force | Out-Null
    New-Item -ItemType Directory -Path "$buildDir/modules" -Force | Out-Null
    
    # Salin file
    Copy-Item -Path "$scriptDir/../src/ui/*" -Destination "$buildDir/ui" -Recurse -Force
    Copy-Item -Path "$scriptDir/../src/modules/*" -Destination "$buildDir/modules" -Recurse -Force
    
    Write-Host "Folder ui/ dan modules/ berhasil disalin ke folder build." -ForegroundColor Green
    Write-Host "Selesai! Anda sekarang dapat mendistribusikan folder 'build/' secara utuh." -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
}
catch {
    Write-Error "Gagal menyalin folder pendukung: $_"
}

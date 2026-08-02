# Windows All-in-One Utility - Activation Module

$global:KeyDatabase = [ordered]@{
    # Windows 10 / 11 Client Keys (HWID Supported)
    "Home"                        = @{ Key = "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"; Method = "HWID" }
    "HomeN"                       = @{ Key = "3KHY7-WNT83-DGQKR-F7HPR-844BM"; Method = "HWID" }
    "Home Single Language"        = @{ Key = "7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH"; Method = "HWID" }
    "Home Country Specific"       = @{ Key = "PVMJN-6DFY6-9CCP6-7FDTT-D3WVR"; Method = "HWID" }
    "Pro"                         = @{ Key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T"; Method = "HWID" }
    "ProN"                        = @{ Key = "4CPRK-NM3K3-X6XXQ-RXX86-WXCHW"; Method = "HWID" }
    "Pro Education"               = @{ Key = "8PTT6-NU4BB-W9X7Y-XX2DM-KY9QP"; Method = "HWID" }
    "Pro EducationN"              = @{ Key = "GJTYN-GDJD8-JJYRC-TJ6VP-DY3GY"; Method = "HWID" }
    "Pro Workstations"            = @{ Key = "DXG7C-N36C4-C4QG5-Y4V33-3V92Y"; Method = "HWID" }
    "Pro WorkstationsN"           = @{ Key = "WYPNQ-8C467-V2W6J-TX4WX-WT2RQ"; Method = "HWID" }
    "Education"                   = @{ Key = "YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY"; Method = "HWID" }
    "EducationN"                  = @{ Key = "84NGF-MHBT6-FXBX8-QWJK7-DRR8H"; Method = "HWID" }
    "Enterprise"                  = @{ Key = "XGVPP-NMH47-7TTHJ-W3FW7-8DEC8"; Method = "HWID" }
    "EnterpriseN"                 = @{ Key = "3V6Q6-NXM87-R4YHF-9H46Y-CC7QH"; Method = "HWID" }
    "EnterpriseS"                 = @{ Key = "M7XTQ-FN8P6-TTKYV-9D4CC-J46GB"; Method = "HWID" } # LTSC 2021
    "EnterpriseS 2019"            = @{ Key = "43TBQ-NH92J-XK8CD-Q8FB6-BFFQ9"; Method = "HWID" } # LTSC 2019
    "EnterpriseS 2016"            = @{ Key = "2D77C-G7M27-2QGBF-FB22X-K3M83"; Method = "HWID" } # LTSB 2016

    # Windows Server KMS GVLK Keys (KMS Fallback)
    "Server 2022 Standard"        = @{ Key = "VDYBN-27WMT-V348H-WJ7WS-T628W"; Method = "KMS" }
    "Server 2022 Datacenter"      = @{ Key = "WX4NQ-8MMHS-WY399-W8X32-8QQ62"; Method = "KMS" }
    "Server 2019 Standard"        = @{ Key = "N69G4-B83C2-QT9QP-WRX9B-PFQJH"; Method = "KMS" }
    "Server 2019 Datacenter"      = @{ Key = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"; Method = "KMS" }
    "Server 2016 Standard"        = @{ Key = "WC2BQ-8NRM3-FDDYY-2BFGV-KCHQY"; Method = "KMS" }
    "Server 2016 Datacenter"      = @{ Key = "CB7KF-BWN84-R7R2Y-793K2-8XDDG"; Method = "KMS" }
}

function Get-ActivationStatus {
    [CmdletBinding()]
    param()
    process {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            
            # Dapatkan status lisensi dari WMI SoftwareLicensingProduct
            # ApplicationID untuk Windows adalah "55c92734-d682-4d71-983e-d6ec3f16059f"
            $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' and PartialProductKey is not null" -ErrorAction SilentlyContinue
            
            $statusStr = "Tidak Diketahui"
            $isActivated = $false
            if ($license) {
                $status = $license.LicenseStatus
                # 1 = Licensed (Activated), 2 = OOB Grace, 3 = OOT Grace, 4 = Non-Genuine Grace, 5 = Notification
                switch ($status) {
                    1 { $statusStr = "Teraktivasi (Permanen / Licensed)"; $isActivated = $true }
                    2 { $statusStr = "Masa Tenggang OOB" }
                    3 { $statusStr = "Masa Tenggang OOT" }
                    4 { $statusStr = "Masa Tenggang Non-Genuine" }
                    5 { $statusStr = "Jendela Notifikasi (Belum Teraktivasi)" }
                    default { $statusStr = "Belum Teraktivasi" }
                }
            }
            
            return [PSCustomObject]@{
                Edition     = $os.Caption
                Version     = $os.Version
                Status      = $statusStr
                IsActivated = $isActivated
            }
        }
        catch {
            Write-Error "Gagal mendeteksi status aktivasi: $_"
            return $null
        }
    }
}

function Start-WindowsActivation {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Memulai pendeteksian edisi OS untuk aktivasi..."
        $status = Get-ActivationStatus
        if (-not $status) {
            Write-Error "Gagal mendeteksi info OS."
            return $false
        }

        Write-Verbose "Edisi terdeteksi: $($status.Edition)"
        
        # Cari key yang cocok berdasarkan nama edisi
        $matchedKey = $null
        $method = $null
        
        # Cari kecocokan exact/partial di database
        foreach ($key in $global:KeyDatabase.Keys) {
            if ($status.Edition -like "*$key*") {
                $matchedKey = $global:KeyDatabase[$key].Key
                $method = $global:KeyDatabase[$key].Method
                break
            }
        }
        
        # Fallback default ke Windows 10/11 Pro jika tidak terdeteksi tapi OS Client
        if (-not $matchedKey) {
            if ($status.Edition -like "*Server*") {
                Write-Verbose "OS Server terdeteksi, default ke Server 2022 Standard KMS..."
                $matchedKey = $global:KeyDatabase["Server 2022 Standard"].Key
                $method = "KMS"
            } else {
                Write-Verbose "Edisi spesifik tidak terdeteksi secara tepat, default ke Windows Pro HWID..."
                $matchedKey = $global:KeyDatabase["Pro"].Key
                $method = "HWID"
            }
        }
        
        Write-Verbose "Metode Aktivasi terpilih: $method"
        Write-Verbose "Generic Key yang akan dipasang: $matchedKey"
        
        # 1. Daftarkan Product Key
        try {
            Write-Verbose "Mendaftarkan product key ke sistem..."
            $service = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
            $service | Invoke-CimMethod -MethodName InstallProductKey -Arguments @{ProductKey = $matchedKey} -ErrorAction Stop
            Write-Verbose "Product key berhasil didaftarkan."
        }
        catch {
            Write-Error "Gagal mendaftarkan product key: $_"
            return $false
        }

        # 2. Eksekusi Aktivasi sesuai metode
        if ($method -eq "HWID") {
            return Invoke-HWIDActivation
        }
        else {
            return Invoke-KMSActivation
        }
    }
}

function Invoke-HWIDActivation {
    Write-Verbose "Memulai proses Digital License (HWID) Ticket..."
    
    $tempDir = "$env:TEMP\Win11OptActivation"
    if (!(Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }
    
    $gatherosstateExe = "$tempDir\gatherosstate.exe"
    $ticketXml = "$tempDir\GenuineTicket.xml"
    
    # Bersihkan file XML lama jika ada
    if (Test-Path $ticketXml) { Remove-Item $ticketXml -Force }
    
    # Unduh gatherosstate.exe secara aman dari repository terpercaya (MAS GitHub)
    Write-Verbose "Mengunduh gatherosstate.exe resmi..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $downloader = New-Object System.Net.WebClient
    $url = "https://github.com/massgravel/Microsoft-Activation-Scripts/raw/main/MAS/All-In-One-Version-KL/bin/gatherosstate.exe"
    
    try {
        $downloader.DownloadFile($url, $gatherosstateExe)
        Write-Verbose "Download selesai."
    }
    catch {
        Write-Error "Gagal mengunduh gatherosstate.exe: $_"
        return $false
    }
    
    # Jalankan gatherosstate.exe untuk menghasilkan tiket lisensi digital
    Write-Verbose "Membuat tiket aktivasi (GenuineTicket.xml)..."
    try {
        $proc = Start-Process -FilePath $gatherosstateExe -WorkingDirectory $tempDir -NoNewWindow -PassThru -Wait
        if ($proc.ExitCode -ne 0) {
            throw "Proses gatherosstate.exe keluar dengan error: $($proc.ExitCode)"
        }
    }
    catch {
        Write-Error "Gagal membuat tiket: $_"
        return $false
    }
    
    if (!(Test-Path $ticketXml)) {
        Write-Error "Tiket GenuineTicket.xml tidak berhasil dibuat oleh gatherosstate."
        return $false
    }
    
    # Pindahkan tiket ke direktori ClipSVC
    $clipSvcDir = "$env:ProgramData\Microsoft\Windows\ClipSVC\GenuineTicket"
    if (!(Test-Path $clipSvcDir)) {
        New-Item -ItemType Directory -Path $clipSvcDir -Force | Out-Null
    }
    
    Write-Verbose "Menyalin tiket ke folder ClipSVC..."
    try {
        Copy-Item -Path $ticketXml -Destination "$clipSvcDir\GenuineTicket.xml" -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Gagal menyalin tiket ke folder ClipSVC: $_"
        return $false
    }
    
    # Restart layanan ClipSVC untuk memproses tiket lisensi digital
    Write-Verbose "Memicu verifikasi lisensi (Restart ClipSVC)..."
    try {
        Restart-Service -Name "ClipSVC" -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Warning "Gagal me-restart ClipSVC: $_. Mencoba melanjutkan aktivasi..."
    }
    
    # Lakukan aktivasi online ke server Microsoft
    Write-Verbose "Menghubungi server aktivasi Microsoft..."
    try {
        $service = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
        $service | Invoke-CimMethod -MethodName RefreshLicenseStatus -ErrorAction SilentlyContinue
        
        # Panggil slmgr.vbs /ato di background
        $proc = Start-Process -FilePath "cscript" -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -PassThru -Wait
        
        # Periksa ulang status
        $finalStatus = Get-ActivationStatus
        if ($finalStatus.IsActivated) {
            Write-Verbose "WINDOWS BERHASIL TERAKTIVASI PERMANEN DENGAN DIGITAL LICENSE!"
            return $true
        } else {
            Write-Warning "Status pasca aktivasi: $($finalStatus.Status)"
            Write-Error "Aktivasi selesai, namun status sistem belum aktif. Silakan jalankan kembali atau periksa koneksi internet."
            return $false
        }
    }
    catch {
        Write-Error "Gagal memicu aktivasi online: $_"
        return $false
    }
    finally {
        # Bersihkan folder temp
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-KMSActivation {
    Write-Verbose "Memulai proses aktivasi KMS Client..."
    
    $kmsServer = "kms8.msguides.com" # Server KMS publik tepercaya
    
    try {
        Write-Verbose "Mengatur server KMS ke: $kmsServer..."
        $service = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
        $service | Invoke-CimMethod -MethodName SetKeyManagementServiceMachine -Arguments @{Name = $kmsServer} -ErrorAction Stop
        Write-Verbose "Server KMS berhasil diatur."
        
        Write-Verbose "Menghubungi server KMS untuk aktivasi..."
        $proc = Start-Process -FilePath "cscript" -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -PassThru -Wait
        
        # Periksa ulang status
        $finalStatus = Get-ActivationStatus
        if ($finalStatus.IsActivated) {
            Write-Verbose "WINDOWS SERVER BERHASIL TERAKTIVASI VIA KMS ($kmsServer)!"
            return $true
        } else {
            Write-Warning "Status pasca aktivasi: $($finalStatus.Status)"
            Write-Error "Gagal mengaktifkan via KMS. Server mungkin sibuk atau koneksi diblokir."
            return $false
        }
    }
    catch {
        Write-Error "Gagal memicu aktivasi KMS: $_"
        return $false
    }
}

Export-ModuleMember -Function Get-ActivationStatus, Start-WindowsActivation

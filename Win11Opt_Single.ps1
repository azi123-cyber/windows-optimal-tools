#Requires -Version 5.1
# =============================================================================
#   Windows All-in-One Utility - SINGLE FILE PORTABLE EDITION
#   Cara Pakai (1 Baris dari PowerShell Admin):
#   irm "URL_RAW_GITHUB_KAMU" | iex
#   Atau jalankan langsung: powershell -STA -ExecutionPolicy Bypass -File Win11Opt_Single.ps1
# =============================================================================

# ============================
# 0. SELF-ELEVATION + STA GUARD
# ============================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSTA   = [System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'

if (-not $isAdmin -or -not $isSTA) {
    # Jika dijalankan via irm | iex, simpan dulu ke file temp lalu relaunch
    if ($PSCommandPath) {
        $argsList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } else {
        # Mode irm | iex : simpan script saat ini ke temp, relaunch dari sana
        $tempScript = "$env:TEMP\Win11Opt_Run.ps1"
        $MyInvocation.MyCommand.ScriptBlock | Out-File -FilePath $tempScript -Encoding UTF8 -Force
        $argsList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
    }

    if (-not $isAdmin) {
        Write-Host "[Win11Opt] Memerlukan hak akses Administrator. Meluncurkan ulang sebagai Admin..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList $argsList -Verb RunAs
    } else {
        Write-Host "[Win11Opt] Memerlukan mode STA. Meluncurkan ulang..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList $argsList
    }
    Exit
}

# ============================
# 1. LOAD WPF ASSEMBLIES
# ============================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

# ============================
# 2. INLINE MODUL: OPTIMIZER
# ============================
function Set-RestorePoint {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Memulai pembuatan Restore Point..."
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Win11Opt_BeforeTweak" -RestorePointType MODIFY_SETTINGS -Confirm:$false
            Write-Verbose "System Restore Point 'Win11Opt_BeforeTweak' berhasil dibuat!"
            return $true
        }
        catch { Write-Error "Gagal membuat Restore Point: $_"; return $false }
    }
}

function Disable-WindowsUpdate {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Menonaktifkan Windows Update..."
        foreach ($service in @("wuauserv","UsoSvc","bits")) {
            try {
                if (Get-Service $service -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $service -Force -ErrorAction Stop
                    Set-Service  -Name $service -StartupType Disabled -ErrorAction Stop
                }
            } catch { Write-Error "Gagal menghentikan $service: $_" }
        }
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate", $auPath) | ForEach-Object {
            if (!(Test-Path $_)) { New-Item -Path $_ -Force | Out-Null }
        }
        try {
            Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
            Write-Verbose "Registry NoAutoUpdate diatur ke 1."
            return $true
        } catch { Write-Error "Gagal mengatur registry Windows Update: $_"; return $false }
    }
}

function Enable-WindowsUpdate {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Mengaktifkan kembali Windows Update..."
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (Test-Path $path) {
            try { Remove-ItemProperty -Path $path -Name "NoAutoUpdate" -ErrorAction SilentlyContinue }
            catch { Set-ItemProperty -Path $path -Name "NoAutoUpdate" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue }
        }
        foreach ($service in @("wuauserv","UsoSvc","bits")) {
            try {
                if (Get-Service $service -ErrorAction SilentlyContinue) {
                    Set-Service  -Name $service -StartupType Automatic -ErrorAction Stop
                    Start-Service -Name $service -ErrorAction Stop
                }
            } catch { Write-Error "Gagal memulai $service: $_" }
        }
        Write-Verbose "Windows Update berhasil diaktifkan kembali."
        return $true
    }
}

function Clear-TempFiles {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Membersihkan file-file sementara..."
        $tempPaths   = @("$env:SystemRoot\Temp\*","$env:TEMP\*","$env:SystemRoot\Prefetch\*")
        $deletedCount = 0; $freedBytes = 0
        foreach ($p in $tempPaths) {
            Write-Verbose "Memproses: $p"
            Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                try { $freedBytes += $_.Length; Remove-Item $_.FullName -Force -Recurse -ErrorAction Stop; $deletedCount++ }
                catch {}
            }
            Get-ChildItem -Path $p -Recurse -Directory -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending | ForEach-Object {
                    try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
                }
        }
        $freedMB = [Math]::Round($freedBytes / 1MB, 2)
        Write-Verbose "Selesai! $deletedCount file dihapus, $freedMB MB dibebaskan."
        return [PSCustomObject]@{ Success=$true; DeletedCount=$deletedCount; FreedSpaceMB=$freedMB }
    }
}

function Optimize-PowerPlan {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Mengatur Power Plan ke Ultimate Performance..."
        try {
            $guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            if ((powercfg -list) -notmatch $guid) { powercfg -duplicatescheme $guid | Out-Null }
            powercfg -setactive $guid
            Write-Verbose "Power Plan berhasil diubah ke Ultimate Performance."
            return $true
        } catch { Write-Error "Gagal mengubah Power Plan: $_"; return $false }
    }
}

# ============================
# 3. INLINE MODUL: DISPLAY FIX
# ============================
function Reset-GraphicsStack {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Mereset Driver Grafis..."
        $ok = $false
        try {
            $adapters = Get-PnpDevice -ClassName Display -Status OK -ErrorAction Stop
            foreach ($a in $adapters) {
                Disable-PnpDevice -InstanceId $a.InstanceId -Confirm:$false -ErrorAction Stop
                Start-Sleep -Milliseconds 500
                Enable-PnpDevice -InstanceId $a.InstanceId -Confirm:$false -ErrorAction Stop
                Write-Verbose "Adapter $($a.FriendlyName) di-restart."
            }
            $ok = $true
        } catch { Write-Warning "PnpDevice gagal: $_. Mencoba DWM..." }
        try {
            Stop-Process -Name dwm -Force -ErrorAction Stop
            Write-Verbose "DWM berhasil dipicu restart."
            $ok = $true
        } catch { Write-Error "Gagal restart DWM: $_" }
        return $ok
    }
}

function Clean-GraphicsRegistry {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Membersihkan cache konfigurasi monitor di registry..."
        $paths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Connectivity",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\ScaleFactors"
        )
        $count = 0
        foreach ($path in $paths) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                    try { Remove-Item -Path $_.PSPath -Recurse -Force; $count++ }
                    catch { Write-Error "Gagal hapus $($_.PSPath): $_" }
                }
            }
        }
        Write-Verbose "Selesai. $count entri dihapus. Colokkan kembali kabel HDMI/DP Anda."
        return ($count -gt 0)
    }
}

# ============================
# 4. INLINE MODUL: SECURITY
# ============================
function Start-DefenderScan {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Memulai Quick Scan Windows Defender..."
        try {
            if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
                Start-MpScan -ScanType QuickScan -ErrorAction Stop
                Write-Verbose "Scan Defender selesai!"
                return $true
            } else {
                $paths = @(
                    "$env:ProgramFiles\Windows Defender\MpCmdRun.exe",
                    "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe"
                )
                $exe = $null
                foreach ($p in $paths) {
                    $r = Resolve-Path $p -ErrorAction SilentlyContinue
                    if ($r) { $exe = $r[-1].Path; break }
                }
                if ($exe) {
                    $proc = Start-Process -FilePath $exe -ArgumentList "-Scan -ScanType 1" -NoNewWindow -PassThru -Wait
                    if ($proc.ExitCode -in @(0,2)) { Write-Verbose "Scan CLI selesai."; return $true }
                    else { throw "MpCmdRun exit code: $($proc.ExitCode)" }
                } else { throw "Windows Defender CLI tidak ditemukan." }
            }
        } catch { Write-Error "Gagal scan: $_"; return $false }
    }
}

# ============================
# 5. INLINE MODUL: BLOATWARE
# ============================
$global:BloatwareMap = [ordered]@{
    "Cortana"                         = "Microsoft.549981C3F5F10"
    "Xbox Suite & Overlay"            = "Microsoft.Xbox*"
    "Skype"                           = "Microsoft.SkypeApp"
    "Movies & TV (Zune Video)"        = "Microsoft.ZuneVideo"
    "Groove Music (Zune Music)"       = "Microsoft.ZuneMusic"
    "Microsoft Office Hub"            = "Microsoft.MicrosoftOfficeHub"
    "Solitaire Collection"            = "Microsoft.MicrosoftSolitaireCollection"
    "Feedback Hub"                    = "Microsoft.WindowsFeedbackHub"
    "Mixed Reality Portal"            = "Microsoft.MixedReality.Portal"
    "Sticky Notes"                    = "Microsoft.MicrosoftStickyNotes"
    "Windows Maps"                    = "Microsoft.WindowsMaps"
    "Phone Link (Your Phone)"         = "Microsoft.YourPhone"
    "MSN Weather"                     = "Microsoft.BingWeather"
    "MSN News"                        = "Microsoft.BingNews"
    "MSN Sports"                      = "Microsoft.BingSports"
    "MSN Finance"                     = "Microsoft.BingFinance"
    "Paint 3D"                        = "Microsoft.MSPaint"
    "3D Viewer"                       = "Microsoft.Microsoft3DViewer"
    "Windows People"                  = "Microsoft.People"
    "OneNote"                         = "Microsoft.Office.OneNote"
    "Get Help"                        = "Microsoft.GetHelp"
    "Mail & Calendar"                 = "Microsoft.windowscommunicationsapps"
    "Clipchamp"                       = "Clipchamp.Clipchamp"
}

function Get-BloatwareStatus {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Memindai daftar bloatware terinstal..."
        try {
            $installed = Get-AppxPackage -AllUsers -ErrorAction Stop | Select-Object -ExpandProperty Name
            $results   = [System.Collections.Generic.List[PSCustomObject]]::new()
            foreach ($key in $global:BloatwareMap.Keys) {
                $pattern = $global:BloatwareMap[$key]
                $found   = $installed | Where-Object { $_ -like $pattern }
                $results.Add([PSCustomObject]@{
                    DisplayName = $key; PackageName = $pattern
                    Type = "UWP"; Installed = [bool]$found
                })
            }
            # Cek OneDrive
            $odInstalled = $false
            if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -or
                Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
                $odInstalled = (Get-Process "OneDrive" -ErrorAction SilentlyContinue) -or
                               (Test-Path "$env:LocalAppData\Microsoft\OneDrive\OneDrive.exe") -or
                               (Test-Path "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe")
            }
            $results.Add([PSCustomObject]@{
                DisplayName = "Microsoft OneDrive"; PackageName = "OneDrive"
                Type = "Win32"; Installed = $odInstalled
            })
            return $results
        } catch { Write-Error "Gagal scan bloatware: $_"; return @() }
    }
}

function Remove-Bloatware {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][PSCustomObject[]]$AppsToUninstall)
    process {
        $ok = 0; $fail = 0
        foreach ($app in $AppsToUninstall) {
            Write-Verbose "Menghapus: $($app.DisplayName)..."
            if ($app.PackageName -eq "OneDrive") {
                try {
                    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    $u64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
                    $u32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
                    if   (Test-Path $u64) { Start-Process -FilePath $u64 -ArgumentList "/uninstall" -NoNewWindow -Wait }
                    elseif (Test-Path $u32) { Start-Process -FilePath $u32 -ArgumentList "/uninstall" -NoNewWindow -Wait }
                    Remove-Item "$env:LocalAppData\Microsoft\OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
                    Remove-Item "$env:ProgramData\Microsoft\OneDrive"  -Force -Recurse -ErrorAction SilentlyContinue
                    $ok++
                } catch { Write-Error "Gagal hapus OneDrive: $_"; $fail++ }
            } else {
                try {
                    $pkgs = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app.PackageName }
                    if ($pkgs) {
                        $pkgs | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop }
                    }
                    $ok++
                } catch { Write-Error "Gagal hapus $($app.DisplayName): $_"; $fail++ }
            }
        }
        Write-Verbose "Selesai. Berhasil: $ok, Gagal: $fail."
        return [PSCustomObject]@{ SuccessCount=$ok; FailCount=$fail }
    }
}

# ============================
# 6. INLINE MODUL: ACTIVATION
# ============================
$global:KeyDatabase = [ordered]@{
    "Home"                        = @{ Key = "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"; Method = "HWID" }
    "HomeN"                       = @{ Key = "3KHY7-WNT83-DGQKR-F7HPR-844BM"; Method = "HWID" }
    "Home Single Language"        = @{ Key = "7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH"; Method = "HWID" }
    "Home Country Specific"       = @{ Key = "PVMJN-6DFY6-9CCP6-7FDTT-D3WVR"; Method = "HWID" }
    "Pro"                         = @{ Key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T"; Method = "HWID" }
    "ProN"                        = @{ Key = "4CPRK-NM3K3-X6XXQ-RXX86-WXCHW"; Method = "HWID" }
    "Pro Education"               = @{ Key = "8PTT6-NU4BB-W9X7Y-XX2DM-KY9QP"; Method = "HWID" }
    "Pro Workstations"            = @{ Key = "DXG7C-N36C4-C4QG5-Y4V33-3V92Y"; Method = "HWID" }
    "Education"                   = @{ Key = "YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY"; Method = "HWID" }
    "Enterprise"                  = @{ Key = "XGVPP-NMH47-7TTHJ-W3FW7-8DEC8"; Method = "HWID" }
    "EnterpriseN"                 = @{ Key = "3V6Q6-NXM87-R4YHF-9H46Y-CC7QH"; Method = "HWID" }
    "EnterpriseS"                 = @{ Key = "M7XTQ-FN8P6-TTKYV-9D4CC-J46GB"; Method = "HWID" }
    "EnterpriseS 2019"            = @{ Key = "43TBQ-NH92J-XK8CD-Q8FB6-BFFQ9"; Method = "HWID" }
    "EnterpriseS 2016"            = @{ Key = "2D77C-G7M27-2QGBF-FB22X-K3M83"; Method = "HWID" }
    "Server 2022 Standard"        = @{ Key = "VDYBN-27WMT-V348H-WJ7WS-T628W"; Method = "KMS"  }
    "Server 2022 Datacenter"      = @{ Key = "WX4NQ-8MMHS-WY399-W8X32-8QQ62"; Method = "KMS"  }
    "Server 2019 Standard"        = @{ Key = "N69G4-B83C2-QT9QP-WRX9B-PFQJH"; Method = "KMS"  }
    "Server 2019 Datacenter"      = @{ Key = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"; Method = "KMS"  }
    "Server 2016 Standard"        = @{ Key = "WC2BQ-8NRM3-FDDYY-2BFGV-KCHQY"; Method = "KMS"  }
    "Server 2016 Datacenter"      = @{ Key = "CB7KF-BWN84-R7R2Y-793K2-8XDDG"; Method = "KMS"  }
}

function Get-ActivationStatus {
    [CmdletBinding()] param()
    process {
        try {
            $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $lic = Get-CimInstance -ClassName SoftwareLicensingProduct `
                   -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' and PartialProductKey is not null" `
                   -ErrorAction SilentlyContinue
            $statusStr = "Belum Teraktivasi"; $isAct = $false
            if ($lic) {
                switch ($lic.LicenseStatus) {
                    1 { $statusStr = "Teraktivasi (Permanen)"; $isAct = $true }
                    2 { $statusStr = "Masa Tenggang OOB" }
                    3 { $statusStr = "Masa Tenggang OOT" }
                    4 { $statusStr = "Non-Genuine Grace" }
                    5 { $statusStr = "Notifikasi (Belum Aktif)" }
                    default { $statusStr = "Belum Teraktivasi" }
                }
            }
            return [PSCustomObject]@{
                Edition=$os.Caption; Version=$os.Version
                Status=$statusStr; IsActivated=$isAct
            }
        } catch { Write-Error "Gagal cek status: $_"; return $null }
    }
}

function Start-WindowsActivation {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Mendeteksi edisi OS..."
        $status = Get-ActivationStatus
        if (-not $status) { Write-Error "Gagal mendeteksi OS."; return $false }
        Write-Verbose "Edisi: $($status.Edition)"
        $matchKey = $null; $method = $null
        foreach ($k in $global:KeyDatabase.Keys) {
            if ($status.Edition -like "*$k*") {
                $matchKey = $global:KeyDatabase[$k].Key
                $method   = $global:KeyDatabase[$k].Method
                break
            }
        }
        if (-not $matchKey) {
            if ($status.Edition -like "*Server*") {
                $matchKey = $global:KeyDatabase["Server 2022 Standard"].Key; $method = "KMS"
            } else {
                $matchKey = $global:KeyDatabase["Pro"].Key; $method = "HWID"
            }
        }
        Write-Verbose "Metode: $method | Key: $matchKey"
        try {
            $svc = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
            $svc | Invoke-CimMethod -MethodName InstallProductKey -Arguments @{ProductKey=$matchKey} -ErrorAction Stop
            Write-Verbose "Product key berhasil didaftarkan."
        } catch { Write-Error "Gagal daftar product key: $_"; return $false }
        if ($method -eq "HWID") { return Invoke-HWIDActivation }
        else { return Invoke-KMSActivation }
    }
}

function Invoke-HWIDActivation {
    Write-Verbose "Memulai HWID Activation..."
    $tempDir = "$env:TEMP\Win11OptActivation"
    if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
    $exe    = "$tempDir\gatherosstate.exe"
    $ticket = "$tempDir\GenuineTicket.xml"
    if (Test-Path $ticket) { Remove-Item $ticket -Force }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/massgravel/Microsoft-Activation-Scripts/raw/main/MAS/All-In-One-Version-KL/bin/gatherosstate.exe"
    try {
        Write-Verbose "Mengunduh gatherosstate.exe..."
        (New-Object System.Net.WebClient).DownloadFile($url, $exe)
        Write-Verbose "Download selesai."
    } catch { Write-Error "Gagal download gatherosstate.exe: $_"; return $false }
    try {
        $p = Start-Process -FilePath $exe -WorkingDirectory $tempDir -NoNewWindow -PassThru -Wait
        if ($p.ExitCode -ne 0) { throw "Exit code: $($p.ExitCode)" }
    } catch { Write-Error "Gagal buat tiket: $_"; return $false }
    if (!(Test-Path $ticket)) { Write-Error "GenuineTicket.xml tidak ditemukan."; return $false }
    $clipSvc = "$env:ProgramData\Microsoft\Windows\ClipSVC\GenuineTicket"
    if (!(Test-Path $clipSvc)) { New-Item -ItemType Directory -Path $clipSvc -Force | Out-Null }
    try {
        Copy-Item -Path $ticket -Destination "$clipSvc\GenuineTicket.xml" -Force
    } catch { Write-Error "Gagal salin tiket ke ClipSVC: $_"; return $false }
    try { Restart-Service -Name "ClipSVC" -Force; Start-Sleep -Seconds 2 }
    catch { Write-Warning "Gagal restart ClipSVC: $_" }
    try {
        (Get-CimInstance -ClassName SoftwareLicensingService) |
            Invoke-CimMethod -MethodName RefreshLicenseStatus -ErrorAction SilentlyContinue
        Start-Process -FilePath "cscript" -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -Wait
        $final = Get-ActivationStatus
        if ($final.IsActivated) { Write-Verbose "WINDOWS TERAKTIVASI PERMANEN!"; return $true }
        else { Write-Error "Aktivasi selesai tapi status belum aktif. Cek koneksi internet."; return $false }
    } catch { Write-Error "Gagal aktivasi online: $_"; return $false }
    finally { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Invoke-KMSActivation {
    Write-Verbose "Memulai KMS Activation..."
    $kmsServer = "kms8.msguides.com"
    try {
        $svc = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
        $svc | Invoke-CimMethod -MethodName SetKeyManagementServiceMachine -Arguments @{Name=$kmsServer} -ErrorAction Stop
        Start-Process -FilePath "cscript" -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -Wait
        $final = Get-ActivationStatus
        if ($final.IsActivated) { Write-Verbose "WINDOWS SERVER TERAKTIVASI VIA KMS!"; return $true }
        else { Write-Error "Gagal aktivasi KMS. Server mungkin sibuk."; return $false }
    } catch { Write-Error "Gagal KMS: $_"; return $false }
}

# ============================
# 7. INLINE XAML UI
# ============================
[xml]$xamlContent = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows All-in-One Utility" Height="700" Width="1000"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#1E1E1E" Foreground="#FFFFFF"
        FontFamily="Segoe UI, Segoe UI Variable, Arial">

    <Window.Resources>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#1A1A1A"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
        </Style>

        <Style x:Key="SidebarTabButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="45"/>
            <Setter Property="Margin" Value="10,2,10,2"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="15,0,0,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                CornerRadius="8" BorderThickness="3,0,0,0" BorderBrush="Transparent">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2A2A2A"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="#555555"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Background" Value="#2B2B2B"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#3D3D3D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="15,10,15,10"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#3A3A3A"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#0078D4"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1F1F1F"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#1A1A1A"/>
                                <Setter Property="Foreground" Value="#666666"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="BorderBrush" Value="#005A9E"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>

        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="#272727"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,15"/>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="240"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- SIDEBAR -->
        <Grid Grid.Column="0" Background="#161616">
            <Grid.RowDefinitions>
                <RowDefinition Height="80"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="140"/>
            </Grid.RowDefinitions>

            <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
                <TextBlock Text="&#x1F6E0;&#xFE0F;" FontSize="26" VerticalAlignment="Center"/>
                <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="WIN11 UTILITY" FontWeight="Bold" FontSize="16" Foreground="#FFFFFF"/>
                    <TextBlock Text="All-in-One Optimizer" FontSize="11" Foreground="#888888"/>
                </StackPanel>
            </StackPanel>

            <StackPanel Grid.Row="1" Margin="0,10,0,0">
                <Button Name="BtnTabDashboard"    Style="{StaticResource SidebarTabButton}" Content="&#x1F4CA;   Dashboard"/>
                <Button Name="BtnTabOptimizer"    Style="{StaticResource SidebarTabButton}" Content="&#x26A1;   Optimizer"/>
                <Button Name="BtnTabDisplayFix"   Style="{StaticResource SidebarTabButton}" Content="&#x1F5A5;&#xFE0F;   Display Fix"/>
                <Button Name="BtnTabSecurityApps" Style="{StaticResource SidebarTabButton}" Content="&#x1F6E1;&#xFE0F;   Security &amp; Apps"/>
                <Button Name="BtnTabActivation"   Style="{StaticResource SidebarTabButton}" Content="&#x1F5DD;&#xFE0F;   Aktivasi Windows"/>
                <Button Name="BtnTabAbout"        Style="{StaticResource SidebarTabButton}" Content="&#x2139;&#xFE0F;   About &amp; Help"/>
            </StackPanel>

            <Border Grid.Row="2" Background="#1D1D1D" BorderBrush="#252525" BorderThickness="0,1,0,0" Padding="20,15,20,15">
                <StackPanel VerticalAlignment="Center">
                    <TextBlock Text="MONITOR PERANGKAT" FontSize="10" FontWeight="Bold" Foreground="#666666" Margin="0,0,0,10"/>
                    <Grid Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Beban CPU" FontSize="11" Foreground="#AAAAAA"/>
                        <TextBlock Name="LblCpuVal" Grid.Column="1" Text="0%" FontSize="11" FontWeight="Bold" Foreground="#0078D4"/>
                    </Grid>
                    <ProgressBar Name="ProgCpu" Height="4" Value="0" Maximum="100" Background="#333333" Foreground="#0078D4" BorderThickness="0"/>
                    <Grid Margin="0,12,0,5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="RAM Terpakai" FontSize="11" Foreground="#AAAAAA"/>
                        <TextBlock Name="LblRamVal" Grid.Column="1" Text="0%" FontSize="11" FontWeight="Bold" Foreground="#107C41"/>
                    </Grid>
                    <ProgressBar Name="ProgRam" Height="4" Value="0" Maximum="100" Background="#333333" Foreground="#107C41" BorderThickness="0"/>
                </StackPanel>
            </Border>
        </Grid>

        <!-- MAIN CONTENT -->
        <Grid Grid.Column="1" Background="#1F1F1F">
            <Grid.RowDefinitions>
                <RowDefinition Height="*"/>
                <RowDefinition Height="180"/>
            </Grid.RowDefinitions>

            <Grid Grid.Row="0" Margin="25,25,25,0">

                <!-- TAB 1: DASHBOARD -->
                <Grid Name="PanelDashboard" Visibility="Visible">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Dashboard Utama" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Pantau status sistem Anda dan lakukan optimalisasi cepat dengan sekali klik." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,0">
                                    <StackPanel>
                                        <TextBlock Text="Informasi OS" FontSize="11" Foreground="#888888" FontWeight="Bold"/>
                                        <TextBlock Name="LblOsName" Text="Windows 10/11" FontSize="15" FontWeight="SemiBold" Margin="0,10,0,2" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Name="LblOsVersion" Text="Build Info" FontSize="12" Foreground="#666666"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="10,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Status Hak Akses" FontSize="11" Foreground="#888888" FontWeight="Bold"/>
                                        <TextBlock Text="Administrator (Elevated)" FontSize="15" FontWeight="SemiBold" Foreground="#107C41" Margin="0,10,0,2"/>
                                        <TextBlock Text="Hak akses penuh diaktifkan" FontSize="12" Foreground="#666666"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            <Border Style="{StaticResource CardBorder}" Background="#2D2010" BorderBrush="#503810">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="180"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center">
                                        <TextBlock Text="&#x2B50;   Optimalisasi Sekali Klik (Quick Boost)" FontSize="16" FontWeight="Bold" Foreground="#F7A22D"/>
                                        <TextBlock Text="Membuat Restore Point otomatis, membersihkan file sementara, dan mengaktifkan Ultimate Performance." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,5,15,0"/>
                                    </StackPanel>
                                    <Button Name="BtnQuickBoost" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Jalankan Boost" VerticalAlignment="Center" Height="40"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 2: OPTIMIZER -->
                <Grid Name="PanelOptimizer" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Modul Optimizer" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Kelola update sistem, tingkatkan kinerja daya, dan bersihkan file sampah." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="280"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="Kontrol Windows Update" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Matikan auto-update untuk menghentikan pembaruan mengganggu, atau aktifkan kembali kapan saja." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Right">
                                        <Button Name="BtnDisableWU" Style="{StaticResource ActionButton}" Content="Nonaktifkan Update" Width="135" Margin="0,0,10,0"/>
                                        <Button Name="BtnEnableWU"  Style="{StaticResource ActionButton}" Content="Aktifkan Update" Width="135"/>
                                    </StackPanel>
                                </Grid>
                            </Border>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,0">
                                    <StackPanel>
                                        <TextBlock Text="Pembersih File Temp" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Hapus file sementara (Temp, Prefetch) yang memperlambat disk." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,15" Height="40"/>
                                        <Button Name="BtnCleanTemp" Style="{StaticResource ActionButton}" Content="Bersihkan Temp Files" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="10,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Ultimate Performance" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Aktifkan rencana daya tersembunyi Windows untuk performa maksimum." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,15" Height="40"/>
                                        <Button Name="BtnUltimatePower" Style="{StaticResource ActionButton}" Content="Aktifkan Power Plan" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="200"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="Buat Restore Point" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Disarankan sebelum tweak besar. Kembalikan sistem ke kondisi semula jika terjadi masalah." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnCreateRestore" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Buat Restore Point" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 3: DISPLAY FIX -->
                <Grid Name="PanelDisplayFix" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Display &amp; HDMI Fix" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Perbaiki masalah output layar, HDMI tidak terdeteksi, atau crash driver grafis." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="200"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="Reset Driver Grafis" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Mematikan dan menghidupkan kembali display adapter secara aman. Berguna jika layar freeze atau berkedip." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnResetGpu" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Reset Driver Grafis" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="200"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="Hapus Cache Konfigurasi Layar (HDMI Fix)" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Menghapus cache resolusi dan koneksi monitor lama di registry. Memaksa Windows mendeteksi ulang monitor dari awal." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnClearDispCache" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Hapus Cache Registry" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 4: SECURITY & APPS -->
                <Grid Name="PanelSecurityApps" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Keamanan &amp; Aplikasi (Bloatware)" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Jalankan scan virus cepat atau pilih aplikasi bawaan Windows yang ingin dihapus." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="280"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,15">
                            <StackPanel>
                                <TextBlock Text="Windows Defender Scan" FontSize="15" FontWeight="Bold"/>
                                <TextBlock Text="Jalankan scan virus cepat di background untuk memastikan sistem bersih dari ancaman aktif." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,20"/>
                                <Button Name="BtnDefenderScan" Style="{StaticResource ActionButton}" Content="Mulai Quick Scan" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </Border>
                        <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="10,0,0,15" Padding="15">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="Pilih Bloatware untuk Dihapus:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/>
                                    <Button Name="BtnScanBloatware" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Scan Terinstal" FontSize="11" Padding="8,4,8,4"/>
                                </Grid>
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,10">
                                    <StackPanel Name="StackBloatware" Margin="5,0,5,0"/>
                                </ScrollViewer>
                                <Grid Grid.Row="2">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Name="LblBloatwareCount" Text="Gunakan tombol 'Scan Terinstal' terlebih dahulu." FontSize="11" Foreground="#888888" VerticalAlignment="Center"/>
                                    <Button Name="BtnUninstallBloatware" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Hapus Aplikasi Terpilih" FontWeight="SemiBold"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>

                <!-- TAB 5: ACTIVATION -->
                <Grid Name="PanelActivation" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Aktivasi Windows Permanent" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Aktifkan Windows Anda secara permanen dengan Lisensi Digital (HWID) resmi Microsoft." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,0">
                                    <StackPanel>
                                        <TextBlock Text="Edisi OS Terdeteksi" FontSize="11" Foreground="#888888" FontWeight="Bold"/>
                                        <TextBlock Name="LblActOsName" Text="Memuat..." FontSize="15" FontWeight="SemiBold" Margin="0,10,0,2" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Name="LblActOsVersion" Text="Build Info" FontSize="12" Foreground="#666666"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="10,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Status Aktivasi" FontSize="11" Foreground="#888888" FontWeight="Bold"/>
                                        <TextBlock Name="LblActStatus" Text="Memeriksa..." FontSize="15" FontWeight="SemiBold" Foreground="#FFFFCC00" Margin="0,10,0,2"/>
                                        <TextBlock Name="LblActMethod" Text="Metode: Mendeteksi..." FontSize="12" Foreground="#666666"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            <Border Style="{StaticResource CardBorder}" Background="#152D15" BorderBrush="#2A502A">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="200"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="&#x26A1;   Jalankan Aktivasi Otomatis (1-Klik)" FontSize="16" FontWeight="Bold" Foreground="#52C452"/>
                                        <TextBlock Text="Mendaftarkan Generic Key resmi untuk edisi OS Anda, mengunduh gatherosstate.exe, menghasilkan GenuineTicket.xml lokal, dan memicu pendaftaran Lisensi Digital permanen." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnStartActivation" Grid.Column="1" Style="{StaticResource AccentButton}" Background="#107C41" BorderBrush="#0B592E" Content="Aktifkan Sekarang" VerticalAlignment="Center" Height="40"/>
                                </Grid>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="&#x2139;&#xFE0F;   Tentang Metode Aktivasi HWID &amp; KMS" FontSize="13" FontWeight="Bold" Margin="0,0,0,5"/>
                                    <TextBlock Text="&#x2022; HWID: Lisensi digital permanen yang terikat dengan hardware motherboard Anda. Setelah aktif, install ulang Windows tidak perlu aktivasi ulang." FontSize="11.5" Foreground="#888888" TextWrapping="Wrap" Margin="0,2,0,2"/>
                                    <TextBlock Text="&#x2022; KMS: Metode fallback untuk Windows Server. Aktif 180 hari dan dapat diperbarui otomatis." FontSize="11.5" Foreground="#888888" TextWrapping="Wrap" Margin="0,2,0,2"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 6: ABOUT -->
                <Grid Name="PanelAbout" Visibility="Collapsed">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Tentang &amp; Bantuan" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Informasi mengenai aplikasi dan panduan singkat penggunaan." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Windows All-in-One Utility v1.0.0" FontSize="15" FontWeight="Bold" Foreground="#0078D4"/>
                                    <TextBlock Text="Aplikasi open-source untuk mengoptimalkan Windows 10/11, mengatasi error HDMI, membersihkan disk, dan membuang bloatware." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,10,0,10"/>
                                    <TextBlock Text="Lisensi: MIT (Bebas digunakan dan dimodifikasi)" FontSize="12" Foreground="#888888"/>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Panduan Singkat &amp; Fitur Keamanan" FontSize="15" FontWeight="Bold" Margin="0,0,0,8"/>
                                    <TextBlock Text="&#x2022; Selalu buat Restore Point sebelum menerapkan tweak besar." FontSize="12" Foreground="#CCCCCC" Margin="0,2,0,2"/>
                                    <TextBlock Text="&#x2022; Antivirus mungkin menandai utilitas ini karena modifikasi registry/service - ini normal karena source code transparan." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,2,0,2"/>
                                    <TextBlock Text="&#x2022; Setelah HDMI Fix, colokkan kembali kabel monitor agar Windows mendeteksi ulang." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,2,0,2"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

            </Grid>

            <!-- CONSOLE LOG PANEL -->
            <Border Grid.Row="1" Background="#161616" BorderBrush="#252525" BorderThickness="0,1,0,0" Padding="25,12,25,15">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Name="LblStatus" Text="Status: Siap." FontSize="12" FontWeight="SemiBold" Foreground="#AAAAAA"/>
                        <TextBlock Grid.Column="1" Text="Console Output" FontSize="11" Foreground="#666666"/>
                    </Grid>
                    <TextBox Name="TxtConsole" Grid.Row="1" Background="#101010" Foreground="#00FF00"
                             BorderBrush="#252525" BorderThickness="1" Padding="8"
                             FontFamily="Consolas, Monospace" FontSize="11.5"
                             IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap" AcceptsReturn="True"/>
                    <ProgressBar Name="ProgressMain" Grid.Row="2" Height="6" Margin="0,8,0,0"
                                 Background="#222222" Foreground="#0078D4" BorderThickness="0"
                                 IsIndeterminate="False" Value="0"/>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
'@

# ============================
# 8. LOAD WINDOW FROM XAML
# ============================
$reader = New-Object System.Xml.XmlNodeReader $xamlContent
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Map kontrol berdasarkan atribut Name
$xamlContent.SelectNodes("//*[@Name]") | ForEach-Object {
    Set-Variable -Name $_.Name -Value $Window.FindName($_.Name) -Scope Script
}

# ============================
# 9. SETUP UI HELPERS
# ============================
$brushConverter = New-Object System.Windows.Media.BrushConverter
$activeBg        = $brushConverter.ConvertFromString("#2B2B2B")
$activeBorder    = $brushConverter.ConvertFromString("#0078D4")
$transparentBrush = [System.Windows.Media.Brushes]::Transparent

$panels     = @($PanelDashboard,$PanelOptimizer,$PanelDisplayFix,$PanelSecurityApps,$PanelActivation,$PanelAbout)
$tabButtons = @($BtnTabDashboard,$BtnTabOptimizer,$BtnTabDisplayFix,$BtnTabSecurityApps,$BtnTabActivation,$BtnTabAbout)

function Switch-Tab($index) {
    for ($i = 0; $i -lt $panels.Count; $i++) {
        if ($i -eq $index) {
            $panels[$i].Visibility      = [System.Windows.Visibility]::Visible
            $tabButtons[$i].Background  = $activeBg
            $tabButtons[$i].BorderBrush = $activeBorder
        } else {
            $panels[$i].Visibility      = [System.Windows.Visibility]::Collapsed
            $tabButtons[$i].Background  = $transparentBrush
            $tabButtons[$i].BorderBrush = $transparentBrush
        }
    }
}

$BtnTabDashboard.Add_Click({    Switch-Tab 0 })
$BtnTabOptimizer.Add_Click({    Switch-Tab 1 })
$BtnTabDisplayFix.Add_Click({   Switch-Tab 2 })
$BtnTabSecurityApps.Add_Click({ Switch-Tab 3 })
$BtnTabActivation.Add_Click({   Refresh-ActivationUI; Switch-Tab 4 })
$BtnTabAbout.Add_Click({        Switch-Tab 5 })
Switch-Tab 0

# Info OS awal
$os = Get-CimInstance Win32_OperatingSystem
$LblOsName.Text    = $os.Caption
$LblOsVersion.Text = "Build: $($os.Version) ($($os.OSArchitecture))"

function Write-ToConsole ($Message, $Level = "Info") {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $Window.Dispatcher.Invoke([Action]{
        $TxtConsole.AppendText("[$timestamp] [$Level] $Message`r`n")
        $TxtConsole.ScrollToEnd()
        $LblStatus.Text = "Status: $Message"
    })
}

function Set-ControlsEnabled ($enabled) {
    $Window.Dispatcher.Invoke([Action]{
        @($BtnTabDashboard,$BtnTabOptimizer,$BtnTabDisplayFix,$BtnTabSecurityApps,
          $BtnTabActivation,$BtnQuickBoost,$BtnDisableWU,$BtnEnableWU,$BtnCleanTemp,
          $BtnUltimatePower,$BtnCreateRestore,$BtnResetGpu,$BtnClearDispCache,
          $BtnDefenderScan,$BtnScanBloatware,$BtnUninstallBloatware,$BtnStartActivation) |
        ForEach-Object { $_.IsEnabled = $enabled }
    })
}

$syncHash = [hashtable]::Synchronized(@{ Window=$Window; TxtConsole=$TxtConsole; LblStatus=$LblStatus })

# ============================
# 10. BACKGROUND TASK ENGINE
# ============================

# Semua fungsi modul yang dibutuhkan di dalam runspace – sebagai string literal
$moduleFunctionsBlock = @'
function Set-RestorePoint { [CmdletBinding()] param()
    process { try { Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Win11Opt_BeforeTweak" -RestorePointType MODIFY_SETTINGS -Confirm:$false
        Write-Verbose "Restore Point dibuat!"; return $true } catch { Write-Error "Gagal: $_"; return $false } } }

function Disable-WindowsUpdate { [CmdletBinding()] param()
    process { foreach ($s in @("wuauserv","UsoSvc","bits")) { try {
        if (Get-Service $s -EA SilentlyContinue) { Stop-Service $s -Force; Set-Service $s -StartupType Disabled }
    } catch { Write-Error "Gagal stop $s: $_" } }
    $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",$p) | % { if (!(Test-Path $_)) { New-Item $_ -Force | Out-Null } }
    try { Set-ItemProperty -Path $p -Name NoAutoUpdate -Value 1 -Type DWord -Force; return $true }
    catch { Write-Error "Registry: $_"; return $false } } }

function Enable-WindowsUpdate { [CmdletBinding()] param()
    process { $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (Test-Path $p) { try { Remove-ItemProperty $p NoAutoUpdate -EA SilentlyContinue } catch { Set-ItemProperty $p NoAutoUpdate 0 -Type DWord -Force -EA SilentlyContinue } }
    foreach ($s in @("wuauserv","UsoSvc","bits")) { try {
        if (Get-Service $s -EA SilentlyContinue) { Set-Service $s -StartupType Automatic; Start-Service $s } } catch { Write-Error "Gagal start $s: $_" } }
    return $true } }

function Clear-TempFiles { [CmdletBinding()] param()
    process { $c=0;$b=0
    @("$env:SystemRoot\Temp\*","$env:TEMP\*","$env:SystemRoot\Prefetch\*") | % { $path=$_
        Get-ChildItem $path -Recurse -File -EA SilentlyContinue | % { try{$b+=$_.Length;Remove-Item $_.FullName -Force -Recurse;$c++}catch{} }
        Get-ChildItem $path -Recurse -Directory -EA SilentlyContinue | Sort FullName -Desc | % { try{Remove-Item $_.FullName -Force -EA SilentlyContinue}catch{} } }
    $mb=[Math]::Round($b/1MB,2); Write-Verbose "Selesai: $c file, $mb MB."; return [PSCustomObject]@{Success=$true;DeletedCount=$c;FreedSpaceMB=$mb} } }

function Optimize-PowerPlan { [CmdletBinding()] param()
    process { try { $g="e9a42b02-d5df-448d-aa00-03f14749eb61"
        if ((powercfg -list) -notmatch $g) { powercfg -duplicatescheme $g | Out-Null }
        powercfg -setactive $g; Write-Verbose "Ultimate Performance aktif."; return $true }
    catch { Write-Error "Gagal: $_"; return $false } } }

function Reset-GraphicsStack { [CmdletBinding()] param()
    process { $ok=$false
    try { Get-PnpDevice -ClassName Display -Status OK | % { Disable-PnpDevice $_.InstanceId -Confirm:$false; Start-Sleep -Ms 500; Enable-PnpDevice $_.InstanceId -Confirm:$false }; $ok=$true } catch { Write-Warning "PnpDevice gagal: $_" }
    try { Stop-Process dwm -Force; $ok=$true } catch { Write-Error "DWM gagal: $_" }; return $ok } }

function Clean-GraphicsRegistry { [CmdletBinding()] param()
    process { $c=0
    @("HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration",
      "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Connectivity",
      "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\ScaleFactors") | % {
        if (Test-Path $_) { Get-ChildItem $_ -EA SilentlyContinue | % { try{Remove-Item $_.PSPath -Recurse -Force;$c++}catch{} } } }
    Write-Verbose "$c entri dihapus."; return ($c -gt 0) } }

function Start-DefenderScan { [CmdletBinding()] param()
    process { try { if (Get-Command Start-MpScan -EA SilentlyContinue) { Start-MpScan -ScanType QuickScan; return $true }
    else { $e=(Resolve-Path "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -EA SilentlyContinue)
        if($e){$p=Start-Process $e.Path "-Scan -ScanType 1" -NoNewWindow -PassThru -Wait; return ($p.ExitCode -in @(0,2))}
        else{throw "Defender CLI tidak ditemukan"} } } catch { Write-Error "Scan gagal: $_"; return $false } } }

$global:BloatwareMap = [ordered]@{
    "Cortana"="Microsoft.549981C3F5F10";"Xbox Suite"="Microsoft.Xbox*";"Skype"="Microsoft.SkypeApp"
    "Movies & TV"="Microsoft.ZuneVideo";"Groove Music"="Microsoft.ZuneMusic"
    "Office Hub"="Microsoft.MicrosoftOfficeHub";"Solitaire"="Microsoft.MicrosoftSolitaireCollection"
    "Feedback Hub"="Microsoft.WindowsFeedbackHub";"Mixed Reality"="Microsoft.MixedReality.Portal"
    "Sticky Notes"="Microsoft.MicrosoftStickyNotes";"Windows Maps"="Microsoft.WindowsMaps"
    "Phone Link"="Microsoft.YourPhone";"MSN Weather"="Microsoft.BingWeather"
    "MSN News"="Microsoft.BingNews";"MSN Sports"="Microsoft.BingSports"
    "Paint 3D"="Microsoft.MSPaint";"3D Viewer"="Microsoft.Microsoft3DViewer"
    "Windows People"="Microsoft.People";"OneNote"="Microsoft.Office.OneNote"
    "Get Help"="Microsoft.GetHelp";"Mail & Calendar"="Microsoft.windowscommunicationsapps"
    "Clipchamp"="Clipchamp.Clipchamp"
}

function Get-BloatwareStatus { [CmdletBinding()] param()
    process { try { $inst=Get-AppxPackage -AllUsers | Select -ExpandProperty Name
        $r=[System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($k in $global:BloatwareMap.Keys) { $p=$global:BloatwareMap[$k]; $f=$inst|Where{$_ -like $p}
            $r.Add([PSCustomObject]@{DisplayName=$k;PackageName=$p;Type="UWP";Installed=[bool]$f}) }
        $od=$false; if((Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe")-or(Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe")){
            $od=(Get-Process OneDrive -EA SilentlyContinue)-or(Test-Path "$env:LocalAppData\Microsoft\OneDrive\OneDrive.exe") }
        $r.Add([PSCustomObject]@{DisplayName="Microsoft OneDrive";PackageName="OneDrive";Type="Win32";Installed=$od})
        return $r } catch { Write-Error "Scan gagal: $_"; return @() } } }

function Remove-Bloatware { [CmdletBinding()] param([PSCustomObject[]]$AppsToUninstall)
    process { $ok=0;$fail=0; foreach ($a in $AppsToUninstall) { Write-Verbose "Hapus: $($a.DisplayName)"
        if ($a.PackageName -eq "OneDrive") { try {
            Stop-Process OneDrive -Force -EA SilentlyContinue; Start-Sleep 1
            if(Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"){Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /uninstall -NoNewWindow -Wait}
            elseif(Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe"){Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" /uninstall -NoNewWindow -Wait}
            $ok++ } catch { Write-Error "OneDrive gagal: $_"; $fail++ }
        } else { try { Get-AppxPackage -AllUsers | Where{$_.Name -like $a.PackageName} |
            %{Remove-AppxPackage $_.PackageFullName -AllUsers}; $ok++ } catch { Write-Error "$($a.DisplayName) gagal: $_"; $fail++ } } }
    return [PSCustomObject]@{SuccessCount=$ok;FailCount=$fail} } }

$global:KeyDatabase = [ordered]@{
    "Home"=@{Key="TX9XD-98N7V-6WMQ6-BX7FG-H8Q99";Method="HWID"};"Pro"=@{Key="VK7JG-NPHTM-C97JM-9MPGT-3V66T";Method="HWID"}
    "Education"=@{Key="YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY";Method="HWID"};"Enterprise"=@{Key="XGVPP-NMH47-7TTHJ-W3FW7-8DEC8";Method="HWID"}
    "EnterpriseS"=@{Key="M7XTQ-FN8P6-TTKYV-9D4CC-J46GB";Method="HWID"}
    "Server 2022 Standard"=@{Key="VDYBN-27WMT-V348H-WJ7WS-T628W";Method="KMS"}
    "Server 2019 Standard"=@{Key="N69G4-B83C2-QT9QP-WRX9B-PFQJH";Method="KMS"}
    "Server 2016 Standard"=@{Key="WC2BQ-8NRM3-FDDYY-2BFGV-KCHQY";Method="KMS"}
}

function Get-ActivationStatus { [CmdletBinding()] param()
    process { try { $os=Get-CimInstance Win32_OperatingSystem
        $lic=Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' and PartialProductKey is not null" -EA SilentlyContinue
        $s="Belum Teraktivasi";$a=$false
        if($lic){switch($lic.LicenseStatus){1{$s="Teraktivasi (Permanen)";$a=$true}2{$s="Grace OOB"}3{$s="Grace OOT"}5{$s="Notifikasi"}default{$s="Belum Aktif"}}}
        return [PSCustomObject]@{Edition=$os.Caption;Version=$os.Version;Status=$s;IsActivated=$a}
    } catch { return $null } } }

function Start-WindowsActivation { [CmdletBinding()] param()
    process { $stat=Get-ActivationStatus; if(!$stat){Write-Error "Gagal baca OS";return $false}
    $key=$null;$mth=$null
    foreach($k in $global:KeyDatabase.Keys){if($stat.Edition -like "*$k*"){$key=$global:KeyDatabase[$k].Key;$mth=$global:KeyDatabase[$k].Method;break}}
    if(!$key){if($stat.Edition -like "*Server*"){$key=$global:KeyDatabase["Server 2022 Standard"].Key;$mth="KMS"}else{$key=$global:KeyDatabase["Pro"].Key;$mth="HWID"}}
    Write-Verbose "Metode: $mth | Key: $key"
    try { $svc=Get-CimInstance SoftwareLicensingService; $svc|Invoke-CimMethod InstallProductKey -Arguments @{ProductKey=$key} } catch { Write-Error "Key gagal: $_"; return $false }
    if($mth -eq "HWID"){
        $td="$env:TEMP\Win11OptAct"; if(!(Test-Path $td)){New-Item -ItemType Directory $td -Force|Out-Null}
        $exe="$td\gatherosstate.exe"; $tix="$td\GenuineTicket.xml"; if(Test-Path $tix){Remove-Item $tix -Force}
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        try{(New-Object Net.WebClient).DownloadFile("https://github.com/massgravel/Microsoft-Activation-Scripts/raw/main/MAS/All-In-One-Version-KL/bin/gatherosstate.exe",$exe)}catch{Write-Error "DL gagal: $_";return $false}
        try{$p=Start-Process $exe -WorkingDirectory $td -NoNewWindow -PassThru -Wait;if($p.ExitCode -ne 0){throw "Exit: $($p.ExitCode)"}}catch{Write-Error "Tiket gagal: $_";return $false}
        if(!(Test-Path $tix)){Write-Error "GenuineTicket tidak ada";return $false}
        $cs="$env:ProgramData\Microsoft\Windows\ClipSVC\GenuineTicket"; if(!(Test-Path $cs)){New-Item -ItemType Directory $cs -Force|Out-Null}
        try{Copy-Item $tix "$cs\GenuineTicket.xml" -Force}catch{Write-Error "Copy tiket gagal: $_";return $false}
        try{Restart-Service ClipSVC -Force;Start-Sleep 2}catch{}
        try{(Get-CimInstance SoftwareLicensingService)|Invoke-CimMethod RefreshLicenseStatus -EA SilentlyContinue
            Start-Process cscript "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -Wait
            $f=Get-ActivationStatus; if($f.IsActivated){Write-Verbose "TERAKTIVASI PERMANEN!";return $true}
            else{Write-Error "Belum aktif pasca proses";return $false}}catch{Write-Error "Aktivasi: $_";return $false}
        finally{Remove-Item $td -Recurse -Force -EA SilentlyContinue}
    } else {
        try{$svc=Get-CimInstance SoftwareLicensingService;$svc|Invoke-CimMethod SetKeyManagementServiceMachine -Arguments @{Name="kms8.msguides.com"}
            Start-Process cscript "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -Wait
            $f=Get-ActivationStatus;if($f.IsActivated){Write-Verbose "KMS OK";return $true}else{Write-Error "KMS gagal";return $false}
        }catch{Write-Error "KMS error: $_";return $false}
    } } }
'@

$commonHeader = [ScriptBlock]::Create(@"
    param(`$sync, `$ignored)
    function Write-Log (`$msg, `$lvl = "Info") {
        `$sync.Window.Dispatcher.Invoke([Action]{
            `$ts = Get-Date -Format "HH:mm:ss"
            `$sync.TxtConsole.AppendText("[`$ts] [`$lvl] `$msg``r``n")
            `$sync.TxtConsole.ScrollToEnd()
            `$sync.LblStatus.Text = "Status: `$msg"
        })
    }
    function Run-CommandWithStreaming { param([ScriptBlock]`$cmd)
        `$out = & `$cmd *>&1
        foreach (`$item in `$out) {
            if (`$item -is [System.Management.Automation.VerboseRecord])  { Write-Log `$item.Message "Info" }
            elseif (`$item -is [System.Management.Automation.WarningRecord]) { Write-Log `$item.Message "Warning" }
            elseif (`$item -is [System.Management.Automation.ErrorRecord])  { Write-Log `$item.Exception.Message "Error" }
            elseif (`$item -is [string]) { Write-Log `$item "Info" }
        }
    }
    $moduleFunctionsBlock
"@)

function Invoke-BackgroundTask {
    param(
        [Parameter(Mandatory=$true)][ScriptBlock]$ScriptBlock,
        [Parameter(Mandatory=$false)][ScriptBlock]$OnComplete = $null,
        [Parameter(Mandatory=$false)][Object[]]$Arguments = @()
    )
    Set-ControlsEnabled $false
    $ProgressMain.IsIndeterminate = $true
    $ps = [PowerShell]::Create()
    $ps.AddScript($ScriptBlock)      | Out-Null
    $ps.AddArgument($syncHash)       | Out-Null
    $ps.AddArgument($null)           | Out-Null  # placeholder modulesDir (tidak dipakai)
    foreach ($arg in $Arguments) { $ps.AddArgument($arg) | Out-Null }
    $asyncResult = $ps.BeginInvoke({
        param($ar)
        $psi = $ar.AsyncState
        $res = $null
        try   { $res = $psi.EndInvoke($ar) }
        catch { $syncHash.Window.Dispatcher.Invoke([Action]{ $TxtConsole.AppendText("[ERROR] $_`r`n") }) }
        $syncHash.Window.Dispatcher.Invoke([Action]{
            if ($OnComplete) { & $OnComplete $res }
            Set-ControlsEnabled $true
            $ProgressMain.IsIndeterminate = $false
            $ProgressMain.Value = 100
        })
        $psi.Dispose()
    }, $ps)
}

# ============================
# 11. ACTIVATION STATUS REFRESH
# ============================
function Refresh-ActivationUI {
    try {
        $act = Get-ActivationStatus
        if ($act) {
            $LblActOsName.Text  = $act.Edition
            $LblActOsVersion.Text = "Build: $($act.Version)"
            $LblActStatus.Text  = $act.Status
            $LblActStatus.Foreground = if ($act.IsActivated) {
                [System.Windows.Media.Brushes]::LimeGreen
            } else {
                $brushConverter.ConvertFromString("#FFFFCC00")
            }
            $LblActMethod.Text = if ($act.Edition -like "*Server*") {
                "Metode: KMS Client Server (Auto)"
            } else {
                "Metode: Digital License (HWID)"
            }
        }
    } catch { Write-ToConsole "Gagal refresh status aktivasi: $_" "Error" }
}

# ============================
# 12. EVENT BINDINGS
# ============================
$BtnQuickBoost.Add_Click({
    Write-ToConsole "Memulai Quick Boost..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @'
        Write-Log "Langkah 1: Membuat Restore Point..."
        Run-CommandWithStreaming { Set-RestorePoint -Verbose }
        Write-Log "Langkah 2: Mengaktifkan Ultimate Performance..."
        Run-CommandWithStreaming { Optimize-PowerPlan -Verbose }
        Write-Log "Langkah 3: Membersihkan file sementara..."
        Run-CommandWithStreaming { Clear-TempFiles -Verbose }
        Write-Log "Quick Boost selesai!" "Info"
'@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnDisableWU.Add_Click({
    Write-ToConsole "Menonaktifkan Windows Update..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Disable-WindowsUpdate -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnEnableWU.Add_Click({
    Write-ToConsole "Mengaktifkan Windows Update..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Enable-WindowsUpdate -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnCleanTemp.Add_Click({
    Write-ToConsole "Membersihkan Temp Files..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Clear-TempFiles -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnUltimatePower.Add_Click({
    Write-ToConsole "Mengaktifkan Ultimate Performance..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Optimize-PowerPlan -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnCreateRestore.Add_Click({
    Write-ToConsole "Membuat System Restore Point..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Set-RestorePoint -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnResetGpu.Add_Click({
    Write-ToConsole "Mereset driver grafis..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Reset-GraphicsStack -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnClearDispCache.Add_Click({
    Write-ToConsole "Membersihkan cache registry monitor..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Clean-GraphicsRegistry -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnDefenderScan.Add_Click({
    Write-ToConsole "Memulai Windows Defender Quick Scan..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Start-DefenderScan -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb
})

$BtnScanBloatware.Add_Click({
    Write-ToConsole "Memindai bloatware terinstal..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Get-BloatwareStatus')
    Invoke-BackgroundTask -ScriptBlock $sb -OnComplete {
        param($results)
        $StackBloatware.Children.Clear()
        $count = 0
        foreach ($app in $results) {
            if ($app.Installed) {
                $cb = New-Object System.Windows.Controls.CheckBox
                $cb.Content    = "$($app.DisplayName) ($($app.Type))"
                $cb.Tag        = $app
                $cb.Margin     = "5,5,5,5"
                $cb.Foreground = [System.Windows.Media.Brushes]::White
                $cb.FontSize   = 12
                $StackBloatware.Children.Add($cb)
                $count++
            }
        }
        if ($count -eq 0) {
            $LblBloatwareCount.Text = "Tidak ditemukan bloatware terinstal!"
            Write-ToConsole "Sistem bersih dari bloatware." "Info"
        } else {
            $LblBloatwareCount.Text = "Ditemukan $count aplikasi bloatware."
            Write-ToConsole "Ditemukan $count bloatware terinstal." "Info"
        }
    }
})

$BtnUninstallBloatware.Add_Click({
    $selected = [System.Collections.Generic.List[PSCustomObject]]::new()
    $StackBloatware.Children | Where-Object { $_.IsChecked } | ForEach-Object { $selected.Add($_.Tag) }
    if ($selected.Count -eq 0) { Write-ToConsole "Pilih setidaknya satu aplikasi." "Info"; return }
    Write-ToConsole "Menghapus $($selected.Count) aplikasi terpilih..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @'
        param($sync2, $ign, $apps)
        Run-CommandWithStreaming { Remove-Bloatware -AppsToUninstall $apps -Verbose }
'@)
    Invoke-BackgroundTask -ScriptBlock $sb -Arguments @(,$selected) -OnComplete {
        Write-ToConsole "Penghapusan selesai. Memindai ulang..." "Info"
        $BtnScanBloatware.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
    }
})

$BtnStartActivation.Add_Click({
    Write-ToConsole "Memulai proses aktivasi Windows..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + 'Run-CommandWithStreaming { Start-WindowsActivation -Verbose }')
    Invoke-BackgroundTask -ScriptBlock $sb -OnComplete {
        Refresh-ActivationUI
        Write-ToConsole "Proses aktivasi selesai." "Info"
    }
})

# ============================
# 13. HARDWARE MONITOR TIMER
# ============================
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({
    try {
        $cpu = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -EA SilentlyContinue).PercentProcessorTime
        $ProgCpu.Value  = $cpu; $LblCpuVal.Text = "$cpu%"
        $osM = Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue
        if ($osM) {
            $ram = [Math]::Round((($osM.TotalVisibleMemorySize - $osM.FreePhysicalMemory) / $osM.TotalVisibleMemorySize) * 100, 0)
            $ProgRam.Value = $ram; $LblRamVal.Text = "$ram%"
        }
    } catch {}
})

$Window.Add_Loaded({
    $timer.Start()
    Refresh-ActivationUI
    Write-ToConsole "Aplikasi berhasil dimuat. Selamat menggunakan Windows All-in-One Utility!" "Info"
})

$Window.Add_Closed({ $timer.Stop() })

# ============================
# 14. SHOW WINDOW
# ============================
Write-ToConsole "Memulai antarmuka Windows All-in-One Utility..."
$Window.ShowDialog() | Out-Null

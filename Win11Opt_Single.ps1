#Requires -Version 5.1
# =============================================================================
#   Windows All-in-One Utility - SINGLE FILE PORTABLE EDITION v1.2
#   Cara Pakai (1 Baris dari PowerShell):
#   irm "https://raw.githubusercontent.com/azi123-cyber/windows-optimal-tools/main/Win11Opt_Single.ps1" | iex
# =============================================================================

# ============================
# 0. SELF-ELEVATION + STA GUARD
# ============================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSTA   = [System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'

if (-not $isAdmin -or -not $isSTA) {
    if ($PSCommandPath) {
        $launchFile = $PSCommandPath
    } else {
        $launchFile = "$env:TEMP\Win11Opt_Run.ps1"
        $scriptContent = $MyInvocation.MyCommand.ScriptBlock
        [System.IO.File]::WriteAllText($launchFile, $scriptContent.ToString(), [System.Text.Encoding]::UTF8)
    }
    $args = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$launchFile`""
    if (-not $isAdmin) {
        Start-Process powershell.exe -ArgumentList $args -Verb RunAs
    } else {
        Start-Process powershell.exe -ArgumentList $args
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
# 2. MODULE: OPTIMIZER
# ============================
function Set-RestorePoint {
    [CmdletBinding()] param()
    process {
        Write-Output "Membuat Restore Point (ini mungkin memakan waktu beberapa menit)..."
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Win11Opt_BeforeTweak" -RestorePointType MODIFY_SETTINGS -Confirm:$false
            Write-Output "Restore Point berhasil dibuat!"
            return $true
        } catch {
            Write-Output "[ERROR] Gagal membuat Restore Point: $($_.Exception.Message)"
            return $false
        }
    }
}

function Disable-WindowsUpdate {
    [CmdletBinding()] param()
    process {
        Write-Output "Menonaktifkan layanan Windows Update..."
        foreach ($svc in @("wuauserv","UsoSvc","bits")) {
            try {
                if (Get-Service $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                    Set-Service  -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                    Write-Output "Service $svc dinonaktifkan."
                }
            } catch {
                Write-Output "[ERROR] Gagal menghentikan ${svc}: $($_.Exception.Message)"
            }
        }
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        foreach ($p in @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate", $auPath)) {
            if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        }
        try {
            Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
            Write-Output "Update otomatis dinonaktifkan via Registry."
            return $true
        } catch {
            Write-Output "[ERROR] Gagal set registry: $($_.Exception.Message)"
            return $false
        }
    }
}

function Enable-WindowsUpdate {
    [CmdletBinding()] param()
    process {
        Write-Output "Mengaktifkan kembali Windows Update..."
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (Test-Path $auPath) {
            try {
                Remove-ItemProperty -Path $auPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
            } catch {
                Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        }
        foreach ($svc in @("wuauserv","UsoSvc","bits")) {
            try {
                if (Get-Service $svc -ErrorAction SilentlyContinue) {
                    Set-Service  -Name $svc -StartupType Automatic -ErrorAction SilentlyContinue
                    Start-Service -Name $svc -ErrorAction SilentlyContinue
                    Write-Output "Service $svc diaktifkan."
                }
            } catch {
                Write-Output "[ERROR] Gagal memulai ${svc}: $($_.Exception.Message)"
            }
        }
        return $true
    }
}

function Clear-TempFiles {
    [CmdletBinding()] param()
    process {
        Write-Output "Membersihkan file sampah dan sementara..."
        $count = 0; $bytes = 0
        $paths = @("$env:SystemRoot\Temp\*","$env:TEMP\*","$env:SystemRoot\Prefetch\*")
        
        foreach ($path in $paths) {
            Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                try { 
                    $bytes += $_.Length
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue 
                    $count++ 
                } catch {}
            }
            Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending | ForEach-Object {
                    try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
                }
        }
        $mb = [Math]::Round($bytes / 1MB, 2)
        Write-Output "Pembersihan selesai: $count file dihapus, $mb MB dibebaskan."
        return [PSCustomObject]@{ Success=$true; DeletedCount=$count; FreedSpaceMB=$mb }
    }
}

function Optimize-PowerPlan {
    [CmdletBinding()] param()
    process {
        Write-Output "Menerapkan Ultimate Performance Power Plan..."
        try {
            $guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            if ((powercfg -list) -notmatch $guid) { powercfg -duplicatescheme $guid | Out-Null }
            powercfg -setactive $guid
            Write-Output "Ultimate Performance telah aktif."
            return $true
        } catch {
            Write-Output "[ERROR] Gagal set Power Plan: $($_.Exception.Message)"
            return $false
        }
    }
}

# ============================
# 3. MODULE: DISPLAY FIX
# ============================
function Reset-GraphicsStack {
    [CmdletBinding()] param()
    process {
        Write-Output "Mereset driver grafis (Layar mungkin berkedip)..."
        $ok = $false
        try {
            Get-PnpDevice -ClassName Display -Status OK -ErrorAction Stop | ForEach-Object {
                Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop
                Start-Sleep -Milliseconds 500
                Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop
                Write-Output "Display adapter $($_.FriendlyName) berhasil di-restart."
            }
            $ok = $true
        } catch { Write-Output "[WARN] Gagal reset via PnpDevice. Mencoba restart DWM..." }
        
        try {
            Stop-Process -Name dwm -Force -ErrorAction Stop
            Write-Output "Desktop Window Manager (DWM) berhasil di-restart."
            $ok = $true
        } catch { Write-Output "[ERROR] Gagal restart DWM: $($_.Exception.Message)" }
        return $ok
    }
}

function Clean-GraphicsRegistry {
    [CmdletBinding()] param()
    process {
        Write-Output "Membersihkan cache registry monitor (HDMI Fix)..."
        $count = 0
        foreach ($path in @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Connectivity",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\ScaleFactors"
        )) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                    try { Remove-Item -Path $_.PSPath -Recurse -Force; $count++ }
                    catch {}
                }
            }
        }
        Write-Output "$count entri cache monitor dihapus. Silakan cabut dan pasang kembali kabel HDMI/DP."
        return ($count -gt 0)
    }
}

# ============================
# 4. MODULE: SECURITY
# ============================
function Start-DefenderScan {
    [CmdletBinding()] param()
    process {
        Write-Output "Memulai Windows Defender Quick Scan..."
        try {
            if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
                Start-MpScan -ScanType QuickScan -ErrorAction Stop
                Write-Output "Windows Defender Scan selesai tanpa error."
                return $true
            } else {
                $resolved = Resolve-Path "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ErrorAction SilentlyContinue
                if (-not $resolved) {
                    $resolved = Resolve-Path "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe" -ErrorAction SilentlyContinue
                }
                if ($resolved) {
                    $exe = $resolved[-1].Path
                    $proc = Start-Process -FilePath $exe -ArgumentList "-Scan -ScanType 1" -NoNewWindow -PassThru -Wait
                    if ($proc.ExitCode -in @(0,2)) { Write-Output "Scan selesai."; return $true }
                    else { throw "MpCmdRun exit: $($proc.ExitCode)" }
                } else { throw "Defender CLI tidak ditemukan." }
            }
        } catch {
            Write-Output "[ERROR] Scan gagal: $($_.Exception.Message)"
            return $false
        }
    }
}

# ============================
# 5. MODULE: BLOATWARE
# ============================
$global:BloatwareMap = [ordered]@{
    "Cortana"              = "Microsoft.549981C3F5F10"
    "Xbox Suite"           = "Microsoft.Xbox*"
    "Skype"                = "Microsoft.SkypeApp"
    "Movies & TV"          = "Microsoft.ZuneVideo"
    "Groove Music"         = "Microsoft.ZuneMusic"
    "Office Hub"           = "Microsoft.MicrosoftOfficeHub"
    "Solitaire"            = "Microsoft.MicrosoftSolitaireCollection"
    "Feedback Hub"         = "Microsoft.WindowsFeedbackHub"
    "Mixed Reality Portal" = "Microsoft.MixedReality.Portal"
    "Sticky Notes"         = "Microsoft.MicrosoftStickyNotes"
    "Windows Maps"         = "Microsoft.WindowsMaps"
    "Phone Link"           = "Microsoft.YourPhone"
    "MSN Weather"          = "Microsoft.BingWeather"
    "MSN News"             = "Microsoft.BingNews"
    "MSN Sports"           = "Microsoft.BingSports"
    "MSN Finance"          = "Microsoft.BingFinance"
    "Paint 3D"             = "Microsoft.MSPaint"
    "3D Viewer"            = "Microsoft.Microsoft3DViewer"
    "Windows People"       = "Microsoft.People"
    "OneNote"              = "Microsoft.Office.OneNote"
    "Get Help"             = "Microsoft.GetHelp"
    "Mail & Calendar"      = "Microsoft.windowscommunicationsapps"
    "Clipchamp"            = "Clipchamp.Clipchamp"
}

function Get-BloatwareStatus {
    [CmdletBinding()] param()
    process {
        Write-Output "Memindai sistem untuk aplikasi bloatware..."
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
            $odInstalled = $false
            $odPaths = @(
                "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
                "$env:SystemRoot\System32\OneDriveSetup.exe"
            )
            if (($odPaths | Where-Object { Test-Path $_ }).Count -gt 0) {
                $odInstalled = ($null -ne (Get-Process "OneDrive" -ErrorAction SilentlyContinue)) -or
                               (Test-Path "$env:LocalAppData\Microsoft\OneDrive\OneDrive.exe") -or
                               (Test-Path "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe")
            }
            $results.Add([PSCustomObject]@{
                DisplayName = "Microsoft OneDrive"; PackageName = "OneDrive"
                Type = "Win32"; Installed = $odInstalled
            })
            return $results
        } catch {
            Write-Output "[ERROR] Scan bloatware gagal: $($_.Exception.Message)"
            return @()
        }
    }
}

function Remove-Bloatware {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][PSCustomObject[]]$AppsToUninstall)
    process {
        $ok = 0; $fail = 0
        foreach ($app in $AppsToUninstall) {
            Write-Output "Menghapus: $($app.DisplayName)..."
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
                } catch { $fail++ }
            } else {
                try {
                    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app.PackageName } |
                        ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop }
                    $ok++
                } catch { $fail++ }
            }
        }
        Write-Output "Proses selesai. Berhasil: $ok, Gagal: $fail."
        return [PSCustomObject]@{ SuccessCount=$ok; FailCount=$fail }
    }
}

# ============================
# 6. MODULE: ACTIVATION
# ============================
$global:KeyDatabase = [ordered]@{
    "Home"               = @{ Key = "TX9XD-98N7V-6WMQ6-BX7FG-H8Q99"; Method = "HWID" }
    "HomeN"              = @{ Key = "3KHY7-WNT83-DGQKR-F7HPR-844BM"; Method = "HWID" }
    "Pro"                = @{ Key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T"; Method = "HWID" }
    "ProN"               = @{ Key = "4CPRK-NM3K3-X6XXQ-RXX86-WXCHW"; Method = "HWID" }
    "Pro Education"      = @{ Key = "8PTT6-NU4BB-W9X7Y-XX2DM-KY9QP"; Method = "HWID" }
    "Pro Workstations"   = @{ Key = "DXG7C-N36C4-C4QG5-Y4V33-3V92Y"; Method = "HWID" }
    "Education"          = @{ Key = "YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY"; Method = "HWID" }
    "Enterprise"         = @{ Key = "XGVPP-NMH47-7TTHJ-W3FW7-8DEC8"; Method = "HWID" }
    "EnterpriseN"        = @{ Key = "3V6Q6-NXM87-R4YHF-9H46Y-CC7QH"; Method = "HWID" }
    "EnterpriseS"        = @{ Key = "M7XTQ-FN8P6-TTKYV-9D4CC-J46GB"; Method = "HWID" }
    "Server 2022 Standard"   = @{ Key = "VDYBN-27WMT-V348H-WJ7WS-T628W"; Method = "KMS" }
    "Server 2022 Datacenter" = @{ Key = "WX4NQ-8MMHS-WY399-W8X32-8QQ62"; Method = "KMS" }
    "Server 2019 Standard"   = @{ Key = "N69G4-B83C2-QT9QP-WRX9B-PFQJH"; Method = "KMS" }
    "Server 2019 Datacenter" = @{ Key = "WMDGN-G9PQG-XVVXX-R3X43-63DFG"; Method = "KMS" }
    "Server 2016 Standard"   = @{ Key = "WC2BQ-8NRM3-FDDYY-2BFGV-KCHQY"; Method = "KMS" }
    "Server 2016 Datacenter" = @{ Key = "CB7KF-BWN84-R7R2Y-793K2-8XDDG"; Method = "KMS" }
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
                    1 { $statusStr = "Teraktivasi"; $isAct = $true }
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
        } catch {
            return $null
        }
    }
}

function Invoke-HWIDActivation {
    Write-Output "Mempersiapkan aktivasi digital (HWID)..."
    $tempDir = "$env:TEMP\Win11OptAct"
    if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
    $exe    = "$tempDir\gatherosstate.exe"
    $ticket = "$tempDir\GenuineTicket.xml"
    if (Test-Path $ticket) { Remove-Item $ticket -Force }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/massgravel/Microsoft-Activation-Scripts/raw/main/MAS/All-In-One-Version-KL/bin/gatherosstate.exe"
    try {
        Write-Output "Mengunduh modul aktivasi..."
        (New-Object System.Net.WebClient).DownloadFile($url, $exe)
    } catch {
        Write-Output "[ERROR] Gagal mengunduh modul: $($_.Exception.Message)"
        return $false
    }
    try {
        Write-Output "Membuat tiket lisensi..."
        $proc = Start-Process -FilePath $exe -WorkingDirectory $tempDir -NoNewWindow -PassThru -Wait
    } catch {
        Write-Output "[ERROR] Gagal buat tiket: $($_.Exception.Message)"
        return $false
    }
    
    $clipSvc = "$env:ProgramData\Microsoft\Windows\ClipSVC\GenuineTicket"
    if (-not (Test-Path $clipSvc)) { New-Item -ItemType Directory -Path $clipSvc -Force | Out-Null }
    try {
        Copy-Item -Path $ticket -Destination "$clipSvc\GenuineTicket.xml" -Force
    } catch {
        Write-Output "[ERROR] Gagal memasang tiket lisensi."
        return $false
    }
    
    try { Restart-Service -Name "ClipSVC" -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 } catch {}

    try {
        Write-Output "Memverifikasi lisensi ke server Microsoft..."
        (Get-CimInstance -ClassName SoftwareLicensingService) | Invoke-CimMethod -MethodName RefreshLicenseStatus -ErrorAction SilentlyContinue
        Start-Process -FilePath "cscript" -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -Wait
        $final = Get-ActivationStatus
        if ($final.IsActivated) { Write-Output "Windows berhasil diaktivasi secara permanen!"; return $true }
        else { Write-Output "[ERROR] Aktivasi gagal. Periksa koneksi internet Anda."; return $false }
    } catch {
        Write-Output "[ERROR] Gagal proses aktivasi akhir: $($_.Exception.Message)"
        return $false
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-KMSActivation {
    Write-Output "Mempersiapkan aktivasi KMS Server..."
    $kmsServer = "kms8.msguides.com"
    try {
        $svc = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
        $svc | Invoke-CimMethod -MethodName SetKeyManagementServiceMachine -Arguments @{Name=$kmsServer} -ErrorAction Stop
        Write-Output "Menghubungi KMS Server..."
        Start-Process -FilePath "cscript" -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" -NoNewWindow -Wait
        $final = Get-ActivationStatus
        if ($final.IsActivated) { Write-Output "Windows Server berhasil diaktivasi via KMS!"; return $true }
        else { Write-Output "[ERROR] KMS Server tidak merespon."; return $false }
    } catch {
        Write-Output "[ERROR] Gagal mengatur KMS Server."
        return $false
    }
}

function Start-WindowsActivation {
    [CmdletBinding()] param()
    process {
        Write-Output "Mendeteksi edisi sistem operasi..."
        $status = Get-ActivationStatus
        if (-not $status) { Write-Output "[ERROR] Gagal mendeteksi OS."; return $false }
        Write-Output "Edisi ditemukan: $($status.Edition)"

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

        try {
            Write-Output "Memasang Product Key..."
            $svc = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
            $svc | Invoke-CimMethod -MethodName InstallProductKey -Arguments @{ProductKey=$matchKey} -ErrorAction Stop
        } catch {
            Write-Output "[ERROR] Gagal memasang product key."
            return $false
        }

        if ($method -eq "HWID") { return Invoke-HWIDActivation }
        else { return Invoke-KMSActivation }
    }
}

# ============================
# 7. INLINE XAML UI (Native Fluent Design)
# ============================
[xml]$xamlContent = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows System Utility" Height="700" Width="1000"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="#202020" Foreground="#FFFFFF"
        FontFamily="Segoe UI Variable, Segoe UI, Arial">
    <Window.Resources>
        <!-- ScrollBar Style -->
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Width" Value="8"/>
        </Style>
        
        <!-- Sidebar Button Style -->
        <Style x:Key="SidebarTabButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#E0E0E0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="40"/>
            <Setter Property="Margin" Value="10,2,10,2"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="12,0,0,0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                CornerRadius="4" BorderThickness="3,0,0,0" BorderBrush="Transparent">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2A2A2A"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#333333"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Main Action Button Style -->
        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#3D3D3D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="15,8,15,8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#353535"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#252525"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#1F1F1F"/>
                                <Setter Property="Foreground" Value="#666666"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Accent Button Style -->
        <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource ActionButton}">
            <Setter Property="Background" Value="#005FB8"/>
            <Setter Property="BorderBrush" Value="#005FB8"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#0078D4"/>
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background" Value="#004A90"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Card Container Style -->
        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="#272727"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="6"/>
            <Setter Property="Padding" Value="20"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="250"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <!-- SIDEBAR -->
        <Grid Grid.Column="0" Background="#181818">
            <Grid.RowDefinitions>
                <RowDefinition Height="80"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="120"/>
            </Grid.RowDefinitions>
            
            <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0,0,0">
                <TextBlock Text="&#xE713;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="22" VerticalAlignment="Center" Foreground="#0078D4"/>
                <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
                    <TextBlock Text="System Utility" FontWeight="SemiBold" FontSize="16" Foreground="#FFFFFF"/>
                    <TextBlock Text="Windows Optimization" FontSize="12" Foreground="#888888"/>
                </StackPanel>
            </StackPanel>
            
            <StackPanel Grid.Row="1" Margin="0,10,0,0">
                <Button Name="BtnTabDashboard" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE80F;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Dashboard" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabOptimizer" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xEC4A;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Optimizer" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabDisplayFix" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE7F4;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Display Fix" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabSecurityApps" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE773;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Security &amp; Apps" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabActivation" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE8D7;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="Windows Activation" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
                <Button Name="BtnTabAbout" Style="{StaticResource SidebarTabButton}">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#xE946;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" Margin="0,0,12,0" FontSize="14" VerticalAlignment="Center"/>
                        <TextBlock Text="About &amp; Help" VerticalAlignment="Center"/>
                    </StackPanel>
                </Button>
            </StackPanel>
            
            <Border Grid.Row="2" Background="#1C1C1C" BorderBrush="#252525" BorderThickness="0,1,0,0" Padding="20,15,20,15">
                <StackPanel VerticalAlignment="Center">
                    <TextBlock Text="SYSTEM RESOURCES" FontSize="10" FontWeight="SemiBold" Foreground="#666666" Margin="0,0,0,10"/>
                    <Grid Margin="0,0,0,4">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Text="CPU Usage" FontSize="11" Foreground="#AAAAAA"/>
                        <TextBlock Name="LblCpuVal" Grid.Column="1" Text="0%" FontSize="11" FontWeight="SemiBold" Foreground="#0078D4"/>
                    </Grid>
                    <ProgressBar Name="ProgCpu" Height="2" Value="0" Maximum="100" Background="#333333" Foreground="#0078D4" BorderThickness="0"/>
                    
                    <Grid Margin="0,12,0,4">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Text="Memory Usage" FontSize="11" Foreground="#AAAAAA"/>
                        <TextBlock Name="LblRamVal" Grid.Column="1" Text="0%" FontSize="11" FontWeight="SemiBold" Foreground="#0078D4"/>
                    </Grid>
                    <ProgressBar Name="ProgRam" Height="2" Value="0" Maximum="100" Background="#333333" Foreground="#0078D4" BorderThickness="0"/>
                </StackPanel>
            </Border>
        </Grid>
        
        <!-- MAIN CONTENT -->
        <Grid Grid.Column="1" Background="#202020">
            <Grid.RowDefinitions>
                <RowDefinition Height="*"/>
                <RowDefinition Height="180"/>
            </Grid.RowDefinitions>
            
            <Grid Grid.Row="0" Margin="30,30,30,0">
                <!-- TAB 1: DASHBOARD -->
                <Grid Name="PanelDashboard" Visibility="Visible">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Dashboard" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="System overview and quick optimization tools." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,12">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,6,0">
                                    <StackPanel>
                                        <TextBlock Text="Operating System" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Name="LblOsName" Text="Windows 10/11" FontSize="16" FontWeight="SemiBold" Margin="0,10,0,4" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Name="LblOsVersion" Text="Build Info" FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="6,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Privilege Level" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Text="Administrator" FontSize="16" FontWeight="SemiBold" Foreground="#429CE3" Margin="0,10,0,4"/>
                                        <TextBlock Text="Full access granted" FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="180"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center">
                                        <TextBlock Text="Quick Boost" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                        <TextBlock Text="Automatically creates a restore point, clears temporary files, and enables the Ultimate Performance power plan." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,20,0"/>
                                    </StackPanel>
                                    <Button Name="BtnQuickBoost" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Run Quick Boost" VerticalAlignment="Center" Height="36"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 2: OPTIMIZER -->
                <Grid Name="PanelOptimizer" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Optimizer" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Manage updates, power plans, and system storage." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="280"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Windows Update Control" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Disable automatic updates to prevent unexpected restarts, or re-enable them when needed." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Right">
                                        <Button Name="BtnDisableWU" Style="{StaticResource ActionButton}" Content="Disable Updates" Width="130" Margin="0,0,10,0"/>
                                        <Button Name="BtnEnableWU"  Style="{StaticResource ActionButton}" Content="Enable Updates" Width="130"/>
                                    </StackPanel>
                                </Grid>
                            </Border>
                            
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,6,0">
                                    <StackPanel>
                                        <TextBlock Text="Temporary Files" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Clear system temp and prefetch folders to free up disk space." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,15" Height="40"/>
                                        <Button Name="BtnCleanTemp" Style="{StaticResource ActionButton}" Content="Clean Temp Files" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="6,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Power Plan" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Enable the hidden Ultimate Performance power plan for maximum hardware efficiency." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,15" Height="40"/>
                                        <Button Name="BtnUltimatePower" Style="{StaticResource ActionButton}" Content="Enable Power Plan" HorizontalAlignment="Left"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="System Restore Point" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Create a system restore point manually before making major changes to the system." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnCreateRestore" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Create Restore Point" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 3: DISPLAY FIX -->
                <Grid Name="PanelDisplayFix" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Display Fix" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Resolve display output issues and clear monitor cache." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Restart Graphics Driver" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Restarts the display adapter and Desktop Window Manager (DWM). Useful for frozen screens or stuttering." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnResetGpu" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Restart Driver" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Clear Monitor Cache" FontSize="15" FontWeight="SemiBold"/>
                                        <TextBlock Text="Clears registry cache for external monitors. Forces Windows to redetect HDMI/DP connections." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnClearDispCache" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Clear Registry Cache" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 4: SECURITY & APPS -->
                <Grid Name="PanelSecurityApps" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Security &amp; Apps" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Scan for threats and remove pre-installed bloatware." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="280"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        
                        <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,12">
                            <StackPanel>
                                <TextBlock Text="Windows Defender" FontSize="15" FontWeight="SemiBold"/>
                                <TextBlock Text="Run a quick scan to ensure the system is free from active threats." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,20"/>
                                <Button Name="BtnDefenderScan" Style="{StaticResource ActionButton}" Content="Run Quick Scan" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </Border>
                        
                        <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="2,0,0,12" Padding="20">
                            <Grid>
                                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,12">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBlock Text="Select bloatware to remove:" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
                                    <Button Name="BtnScanBloatware" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Scan Apps" FontSize="11" Padding="12,4,12,4"/>
                                </Grid>
                                
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,15">
                                    <StackPanel Name="StackBloatware" Margin="2,0,2,0"/>
                                </ScrollViewer>
                                
                                <Grid Grid.Row="2">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBlock Name="LblBloatwareCount" Text="Click 'Scan Apps' to discover installed bloatware." FontSize="11" Foreground="#888888" VerticalAlignment="Center"/>
                                    <Button Name="BtnUninstallBloatware" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Remove Selected"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>

                <!-- TAB 5: ACTIVATION -->
                <Grid Name="PanelActivation" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="Windows Activation" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Permanently activate Windows using digital licensing." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,12">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,6,0">
                                    <StackPanel>
                                        <TextBlock Text="Detected Edition" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Name="LblActOsName" Text="Loading..." FontSize="16" FontWeight="SemiBold" Margin="0,10,0,4" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Name="LblActOsVersion" Text="Build Info" FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                                <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="6,0,0,0">
                                    <StackPanel>
                                        <TextBlock Text="License Status" FontSize="12" Foreground="#888888" FontWeight="SemiBold"/>
                                        <TextBlock Name="LblActStatus" Text="Checking..." FontSize="16" FontWeight="SemiBold" Foreground="#E3A742" Margin="0,10,0,4"/>
                                        <TextBlock Name="LblActMethod" Text="Method: Detecting..." FontSize="12" Foreground="#888888"/>
                                    </StackPanel>
                                </Border>
                            </Grid>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                                        <TextBlock Text="Run Activation Setup" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                        <TextBlock Text="Automatically determines the best method (HWID for Client, KMS for Server) and registers the license." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnStartActivation" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Activate Windows" VerticalAlignment="Center" Height="36"/>
                                </Grid>
                            </Border>
                            
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Information" FontSize="13" FontWeight="SemiBold" Margin="0,0,0,8"/>
                                    <TextBlock Text="HWID: Digital license permanently tied to hardware. Survives OS reinstallations." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,2,0,4"/>
                                    <TextBlock Text="KMS: Used for Server editions. Activates for 180 days and auto-renews." FontSize="12" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,2,0,0"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>

                <!-- TAB 6: ABOUT -->
                <Grid Name="PanelAbout" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,25">
                        <TextBlock Text="About &amp; Help" FontSize="26" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Application information and usage guidelines." FontSize="13" Foreground="#AAAAAA" Margin="0,4,0,0"/>
                    </StackPanel>
                    
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Windows System Utility v1.2" FontSize="16" FontWeight="SemiBold" Foreground="#FFFFFF"/>
                                    <TextBlock Text="An open-source utility to optimize Windows, fix display issues, clean storage, and manage bloatware. Designed with native Fluent design principles." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,8,0,15"/>
                                    <TextBlock Text="License: MIT (Free and Open Source)" FontSize="12" Foreground="#888888"/>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Usage Guidelines" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,10"/>
                                    <TextBlock Text="• Always create a Restore Point before applying major optimizations." FontSize="13" Foreground="#AAAAAA" Margin="0,3,0,3"/>
                                    <TextBlock Text="• Antivirus software might flag this utility due to registry modifications." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,3,0,3"/>
                                    <TextBlock Text="• After applying the HDMI Fix, reconnect the monitor cable to force redetection." FontSize="13" Foreground="#AAAAAA" TextWrapping="Wrap" Margin="0,3,0,3"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>
            </Grid>

            <!-- CONSOLE LOG PANEL -->
            <Border Grid.Row="1" Background="#181818" BorderBrush="#2A2A2A" BorderThickness="0,1,0,0" Padding="30,15,30,15">
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,8">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Name="LblStatus" Text="Ready." FontSize="12" FontWeight="SemiBold" Foreground="#CCCCCC"/>
                        <TextBlock Grid.Column="1" Text="Process Output" FontSize="11" Foreground="#666666"/>
                    </Grid>
                    
                    <TextBox Name="TxtConsole" Grid.Row="1" Background="#121212" Foreground="#CCCCCC"
                             BorderBrush="#252525" BorderThickness="1" Padding="10"
                             FontFamily="Consolas, Courier New, Monospace" FontSize="11"
                             IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                             TextWrapping="Wrap" AcceptsReturn="True"/>
                             
                    <ProgressBar Name="ProgressMain" Grid.Row="2" Height="4" Margin="0,10,0,0"
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
$xamlContent.SelectNodes("//*[@Name]") | ForEach-Object {
    Set-Variable -Name $_.Name -Value $Window.FindName($_.Name) -Scope Script
}

# ============================
# 9. UI HELPERS
# ============================
$brushConverter  = New-Object System.Windows.Media.BrushConverter
$activeBg        = $brushConverter.ConvertFromString("#2D2D2D")
$activeBorder    = $brushConverter.ConvertFromString("#0078D4")
$activeText      = $brushConverter.ConvertFromString("#FFFFFF")
$inactiveText    = $brushConverter.ConvertFromString("#E0E0E0")
$transparentBrush = [System.Windows.Media.Brushes]::Transparent

$panels     = @($PanelDashboard,$PanelOptimizer,$PanelDisplayFix,$PanelSecurityApps,$PanelActivation,$PanelAbout)
$tabButtons = @($BtnTabDashboard,$BtnTabOptimizer,$BtnTabDisplayFix,$BtnTabSecurityApps,$BtnTabActivation,$BtnTabAbout)

function Switch-Tab ($index) {
    for ($i = 0; $i -lt $panels.Count; $i++) {
        if ($i -eq $index) {
            $panels[$i].Visibility      = [System.Windows.Visibility]::Visible
            $tabButtons[$i].Background  = $activeBg
            $tabButtons[$i].BorderBrush = $activeBorder
            $tabButtons[$i].Foreground  = $activeText
        } else {
            $panels[$i].Visibility      = [System.Windows.Visibility]::Collapsed
            $tabButtons[$i].Background  = $transparentBrush
            $tabButtons[$i].BorderBrush = $transparentBrush
            $tabButtons[$i].Foreground  = $inactiveText
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

$os = Get-CimInstance Win32_OperatingSystem
$LblOsName.Text    = $os.Caption
$LblOsVersion.Text = "Build: $($os.Version) ($($os.OSArchitecture))"

$syncHash = [hashtable]::Synchronized(@{
    Window     = $Window
    TxtConsole = $TxtConsole
    LblStatus  = $LblStatus
})

function Write-ToConsole ($Message, $Level = "INFO") {
    $ts = Get-Date -Format "HH:mm:ss"
    $Window.Dispatcher.Invoke([Action]{
        $TxtConsole.AppendText("[$ts] [$Level] $Message`r`n")
        $TxtConsole.ScrollToEnd()
        $LblStatus.Text = $Message
    })
}

$allButtons = @(
    $BtnTabDashboard,$BtnTabOptimizer,$BtnTabDisplayFix,$BtnTabSecurityApps,$BtnTabActivation,
    $BtnQuickBoost,$BtnDisableWU,$BtnEnableWU,$BtnCleanTemp,$BtnUltimatePower,
    $BtnCreateRestore,$BtnResetGpu,$BtnClearDispCache,$BtnDefenderScan,
    $BtnScanBloatware,$BtnUninstallBloatware,$BtnStartActivation
)

function Set-ControlsEnabled ($enabled) {
    $Window.Dispatcher.Invoke([Action]{
        foreach ($btn in $allButtons) { $btn.IsEnabled = $enabled }
    })
}

# ============================
# 10. BACKGROUND TASK ENGINE
# ============================
$script:RunspaceFunctionNames = @(
    'Set-RestorePoint','Disable-WindowsUpdate','Enable-WindowsUpdate',
    'Clear-TempFiles','Optimize-PowerPlan','Reset-GraphicsStack','Clean-GraphicsRegistry',
    'Start-DefenderScan','Get-BloatwareStatus','Remove-Bloatware',
    'Get-ActivationStatus','Start-WindowsActivation','Invoke-HWIDActivation','Invoke-KMSActivation'
)

function New-TaskRunspace {
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    foreach ($name in $script:RunspaceFunctionNames) {
        $fn = Get-Item "Function:\$name" -ErrorAction SilentlyContinue
        if ($fn) {
            $entry = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($name, $fn.Definition)
            $iss.Commands.Add($entry)
        }
    }
    $vars = @(
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('BloatwareMap', $global:BloatwareMap, $null),
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('KeyDatabase',  $global:KeyDatabase,  $null),
        [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new('syncHash',     $syncHash,            $null)
    )
    foreach ($v in $vars) { $iss.Variables.Add($v) }

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $rs.Open()
    return $rs
}

function Invoke-BackgroundTask {
    param(
        [Parameter(Mandatory=$true)][ScriptBlock]$Task,
        [Parameter(Mandatory=$false)][ScriptBlock]$OnComplete = $null,
        [Parameter(Mandatory=$false)][Object[]]$Arguments = @()
    )
    Set-ControlsEnabled $false
    $ProgressMain.IsIndeterminate = $true

    $rs = New-TaskRunspace
    $ps = [PowerShell]::Create()
    $ps.Runspace = $rs

    # Simplified logging to prevent UI thread starvation (lag)
    $ps.AddScript({
        function Write-Log ($msg) {
            $syncHash.Window.Dispatcher.Invoke([Action]{
                $ts = Get-Date -Format "HH:mm:ss"
                $syncHash.TxtConsole.AppendText("[$ts] [PROCESS] $msg`r`n")
                $syncHash.TxtConsole.ScrollToEnd()
                $syncHash.LblStatus.Text = $msg
            })
        }
        function Run-CommandQuietly ([ScriptBlock]$cmd) {
            # Execute without streaming every single verbose object to prevent WPF lag
            $results = & $cmd
            if ($results) {
                foreach ($r in $results) {
                    if ($r -is [string]) { Write-Log $r }
                }
            }
        }
    }) | Out-Null
    $ps.Invoke() | Out-Null
    $ps.Commands.Clear()

    $ps.AddScript($Task) | Out-Null
    foreach ($arg in $Arguments) { $ps.AddArgument($arg) | Out-Null }

    $capturedOnComplete = $OnComplete
    $capturedSyncHash   = $syncHash

    $ps.BeginInvoke({
        param($ar)
        $psi = $ar.AsyncState
        $res = $null
        try { $res = $psi.EndInvoke($ar) }
        catch {
            $capturedSyncHash.Window.Dispatcher.Invoke([Action]{
                $capturedSyncHash.TxtConsole.AppendText("[ERROR] $($_.Exception.Message)`r`n")
            })
        }
        $capturedSyncHash.Window.Dispatcher.Invoke([Action]{
            if ($capturedOnComplete) { & $capturedOnComplete $res }
            Set-ControlsEnabled $true
            $ProgressMain.IsIndeterminate = $false
            $ProgressMain.Value = 100
        })
        $psi.Dispose()
        $rs.Close()
    }, $ps) | Out-Null
}

# ============================
# 11. ACTIVATION STATUS REFRESH
# ============================
function Refresh-ActivationUI {
    try {
        $act = Get-ActivationStatus
        if ($act) {
            $LblActOsName.Text    = $act.Edition
            $LblActOsVersion.Text = "Build: $($act.Version)"
            $LblActStatus.Text    = $act.Status
            $LblActStatus.Foreground = if ($act.IsActivated) {
                [System.Windows.Media.Brushes]::LimeGreen
            } else {
                $brushConverter.ConvertFromString("#E3A742")
            }
            $LblActMethod.Text = if ($act.Edition -like "*Server*") {
                "Method: KMS Server Auto-renewal"
            } else {
                "Method: HWID Digital License"
            }
        }
    } catch {
        Write-ToConsole "Failed to refresh activation status." "ERROR"
    }
}

# ============================
# 12. EVENT BINDINGS
# ============================
$BtnQuickBoost.Add_Click({
    Write-ToConsole "Starting Quick Boost..."
    Invoke-BackgroundTask -Task {
        Run-CommandQuietly { Set-RestorePoint }
        Run-CommandQuietly { Optimize-PowerPlan }
        Run-CommandQuietly { Clear-TempFiles }
        Write-Log "Quick Boost completed successfully."
    }
})

$BtnDisableWU.Add_Click({
    Write-ToConsole "Disabling Windows Update..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Disable-WindowsUpdate } }
})

$BtnEnableWU.Add_Click({
    Write-ToConsole "Enabling Windows Update..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Enable-WindowsUpdate } }
})

$BtnCleanTemp.Add_Click({
    Write-ToConsole "Cleaning temporary files..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Clear-TempFiles } }
})

$BtnUltimatePower.Add_Click({
    Write-ToConsole "Applying Ultimate Performance plan..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Optimize-PowerPlan } }
})

$BtnCreateRestore.Add_Click({
    Write-ToConsole "Creating System Restore Point..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Set-RestorePoint } }
})

$BtnResetGpu.Add_Click({
    Write-ToConsole "Restarting graphics drivers..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Reset-GraphicsStack } }
})

$BtnClearDispCache.Add_Click({
    Write-ToConsole "Clearing monitor registry cache..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Clean-GraphicsRegistry } }
})

$BtnDefenderScan.Add_Click({
    Write-ToConsole "Starting Windows Defender scan..."
    Invoke-BackgroundTask -Task { Run-CommandQuietly { Start-DefenderScan } }
})

$BtnScanBloatware.Add_Click({
    Write-ToConsole "Scanning for bloatware..."
    Invoke-BackgroundTask -Task {
        return Get-BloatwareStatus
    } -OnComplete {
        param($results)
        $StackBloatware.Children.Clear()
        $count = 0
        foreach ($app in $results) {
            if ($app.Installed) {
                $cb            = New-Object System.Windows.Controls.CheckBox
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
            $LblBloatwareCount.Text = "System is clean. No bloatware found."
            Write-ToConsole "Scan completed. No bloatware detected."
        } else {
            $LblBloatwareCount.Text = "Found $count installed bloatware apps."
            Write-ToConsole "Scan completed. Found $count bloatware apps."
        }
    }
})

$BtnUninstallBloatware.Add_Click({
    $selected = [System.Collections.Generic.List[PSCustomObject]]::new()
    $StackBloatware.Children | Where-Object { $_.IsChecked } | ForEach-Object { $selected.Add($_.Tag) }
    if ($selected.Count -eq 0) {
        Write-ToConsole "Please select at least one application."
        return
    }
    Write-ToConsole "Removing $($selected.Count) selected applications..."
    $appsToPass = $selected.ToArray()
    Invoke-BackgroundTask -Task {
        param($apps)
        Write-Log "Starting removal process..."
        Run-CommandQuietly { Remove-Bloatware -AppsToUninstall $apps }
    } -Arguments @(,$appsToPass) -OnComplete {
        Write-ToConsole "Removal finished. Rescanning..."
        $BtnScanBloatware.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
    }
})

$BtnStartActivation.Add_Click({
    Write-ToConsole "Starting Windows activation..."
    Invoke-BackgroundTask -Task {
        Run-CommandQuietly { Start-WindowsActivation }
    } -OnComplete {
        Refresh-ActivationUI
        Write-ToConsole "Activation sequence completed."
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
        if ($null -ne $cpu) { $ProgCpu.Value = $cpu; $LblCpuVal.Text = "$cpu%" }
        $osm = Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue
        if ($osm) {
            $ram = [Math]::Round((($osm.TotalVisibleMemorySize - $osm.FreePhysicalMemory) / $osm.TotalVisibleMemorySize) * 100, 0)
            $ProgRam.Value = $ram; $LblRamVal.Text = "$ram%"
        }
    } catch {}
})

$Window.Add_Loaded({
    $timer.Start()
    Refresh-ActivationUI
    Write-ToConsole "Application loaded successfully. Welcome!" "INFO"
})
$Window.Add_Closed({ $timer.Stop() })

# ============================
# 14. SHOW WINDOW
# ============================
$Window.ShowDialog() | Out-Null

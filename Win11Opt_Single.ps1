#Requires -Version 5.1
# =============================================================================
#   Windows All-in-One Utility - SINGLE FILE PORTABLE EDITION v1.1
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
        # Mode irm | iex: simpan ke temp file dulu
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
        Write-Verbose "Membuat Restore Point..."
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Win11Opt_BeforeTweak" -RestorePointType MODIFY_SETTINGS -Confirm:$false
            Write-Verbose "Restore Point berhasil dibuat!"
            return $true
        } catch {
            Write-Error "Gagal membuat Restore Point: $($_.Exception.Message)"
            return $false
        }
    }
}

function Disable-WindowsUpdate {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Menonaktifkan Windows Update..."
        foreach ($svc in @("wuauserv","UsoSvc","bits")) {
            try {
                if (Get-Service $svc -ErrorAction SilentlyContinue) {
                    Stop-Service -Name $svc -Force -ErrorAction Stop
                    Set-Service  -Name $svc -StartupType Disabled -ErrorAction Stop
                    Write-Verbose "Service $svc dinonaktifkan."
                }
            } catch {
                Write-Error "Gagal menghentikan ${svc}: $($_.Exception.Message)"
            }
        }
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        foreach ($p in @("HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate", $auPath)) {
            if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        }
        try {
            Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
            Write-Verbose "Registry NoAutoUpdate diatur ke 1."
            return $true
        } catch {
            Write-Error "Gagal set registry: $($_.Exception.Message)"
            return $false
        }
    }
}

function Enable-WindowsUpdate {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Mengaktifkan Windows Update..."
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
                    Set-Service  -Name $svc -StartupType Automatic -ErrorAction Stop
                    Start-Service -Name $svc -ErrorAction Stop
                    Write-Verbose "Service $svc diaktifkan."
                }
            } catch {
                Write-Error "Gagal memulai ${svc}: $($_.Exception.Message)"
            }
        }
        return $true
    }
}

function Clear-TempFiles {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Membersihkan file sementara..."
        $count = 0; $bytes = 0
        foreach ($path in @("$env:SystemRoot\Temp\*","$env:TEMP\*","$env:SystemRoot\Prefetch\*")) {
            Write-Verbose "Memproses: $path"
            Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                try { $bytes += $_.Length; Remove-Item $_.FullName -Force -Recurse; $count++ } catch {}
            }
            Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending | ForEach-Object {
                    try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
                }
        }
        $mb = [Math]::Round($bytes / 1MB, 2)
        Write-Verbose "Selesai: $count file dihapus, $mb MB dibebaskan."
        return [PSCustomObject]@{ Success=$true; DeletedCount=$count; FreedSpaceMB=$mb }
    }
}

function Optimize-PowerPlan {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Mengatur Ultimate Performance..."
        try {
            $guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            if ((powercfg -list) -notmatch $guid) { powercfg -duplicatescheme $guid | Out-Null }
            powercfg -setactive $guid
            Write-Verbose "Ultimate Performance aktif."
            return $true
        } catch {
            Write-Error "Gagal set Power Plan: $($_.Exception.Message)"
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
        Write-Verbose "Mereset driver grafis..."
        $ok = $false
        try {
            Get-PnpDevice -ClassName Display -Status OK -ErrorAction Stop | ForEach-Object {
                Disable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop
                Start-Sleep -Milliseconds 500
                Enable-PnpDevice -InstanceId $_.InstanceId -Confirm:$false -ErrorAction Stop
                Write-Verbose "Adapter $($_.FriendlyName) di-restart."
            }
            $ok = $true
        } catch { Write-Warning "PnpDevice gagal: $($_.Exception.Message). Mencoba DWM..." }
        try {
            Stop-Process -Name dwm -Force -ErrorAction Stop
            Write-Verbose "DWM dipicu restart."
            $ok = $true
        } catch { Write-Error "Gagal restart DWM: $($_.Exception.Message)" }
        return $ok
    }
}

function Clean-GraphicsRegistry {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Membersihkan cache registry monitor..."
        $count = 0
        foreach ($path in @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Connectivity",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\ScaleFactors"
        )) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                    try { Remove-Item -Path $_.PSPath -Recurse -Force; $count++ }
                    catch { Write-Error "Gagal hapus $($_.Name): $($_.Exception.Message)" }
                }
            }
        }
        Write-Verbose "$count entri dihapus. Colokkan kembali kabel HDMI/DP."
        return ($count -gt 0)
    }
}

# ============================
# 4. MODULE: SECURITY
# ============================
function Start-DefenderScan {
    [CmdletBinding()] param()
    process {
        Write-Verbose "Memulai Windows Defender Quick Scan..."
        try {
            if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
                Start-MpScan -ScanType QuickScan -ErrorAction Stop
                Write-Verbose "Scan selesai!"
                return $true
            } else {
                $resolved = Resolve-Path "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -ErrorAction SilentlyContinue
                if (-not $resolved) {
                    $resolved = Resolve-Path "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe" -ErrorAction SilentlyContinue
                }
                if ($resolved) {
                    $exe = $resolved[-1].Path
                    $proc = Start-Process -FilePath $exe -ArgumentList "-Scan -ScanType 1" -NoNewWindow -PassThru -Wait
                    if ($proc.ExitCode -in @(0,2)) { Write-Verbose "Scan CLI selesai."; return $true }
                    else { throw "MpCmdRun exit: $($proc.ExitCode)" }
                } else { throw "Defender CLI tidak ditemukan." }
            }
        } catch {
            Write-Error "Scan gagal: $($_.Exception.Message)"
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
        Write-Verbose "Memindai bloatware..."
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
            Write-Error "Scan bloatware gagal: $($_.Exception.Message)"
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
                    Write-Verbose "OneDrive dihapus."
                    $ok++
                } catch {
                    Write-Error "Gagal hapus OneDrive: $($_.Exception.Message)"
                    $fail++
                }
            } else {
                try {
                    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app.PackageName } |
                        ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop }
                    Write-Verbose "$($app.DisplayName) dihapus."
                    $ok++
                } catch {
                    Write-Error "Gagal hapus $($app.DisplayName): $($_.Exception.Message)"
                    $fail++
                }
            }
        }
        Write-Verbose "Selesai. Berhasil: $ok, Gagal: $fail."
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
        } catch {
            Write-Error "Gagal cek aktivasi: $($_.Exception.Message)"
            return $null
        }
    }
}

function Invoke-HWIDActivation {
    Write-Verbose "Memulai HWID Activation..."
    $tempDir = "$env:TEMP\Win11OptAct"
    if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
    $exe    = "$tempDir\gatherosstate.exe"
    $ticket = "$tempDir\GenuineTicket.xml"
    if (Test-Path $ticket) { Remove-Item $ticket -Force }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://github.com/massgravel/Microsoft-Activation-Scripts/raw/main/MAS/All-In-One-Version-KL/bin/gatherosstate.exe"
    try {
        Write-Verbose "Mengunduh gatherosstate.exe..."
        (New-Object System.Net.WebClient).DownloadFile($url, $exe)
        Write-Verbose "Download selesai."
    } catch {
        Write-Error "Gagal download: $($_.Exception.Message)"
        return $false
    }
    try {
        $proc = Start-Process -FilePath $exe -WorkingDirectory $tempDir -NoNewWindow -PassThru -Wait
        if ($proc.ExitCode -ne 0) { throw "Exit code: $($proc.ExitCode)" }
    } catch {
        Write-Error "Gagal buat tiket: $($_.Exception.Message)"
        return $false
    }
    if (-not (Test-Path $ticket)) { Write-Error "GenuineTicket.xml tidak ditemukan."; return $false }

    $clipSvc = "$env:ProgramData\Microsoft\Windows\ClipSVC\GenuineTicket"
    if (-not (Test-Path $clipSvc)) { New-Item -ItemType Directory -Path $clipSvc -Force | Out-Null }
    try {
        Copy-Item -Path $ticket -Destination "$clipSvc\GenuineTicket.xml" -Force
    } catch {
        Write-Error "Gagal salin tiket: $($_.Exception.Message)"
        return $false
    }
    try { Restart-Service -Name "ClipSVC" -Force; Start-Sleep -Seconds 2 }
    catch { Write-Warning "ClipSVC restart gagal, melanjutkan..." }

    try {
        (Get-CimInstance -ClassName SoftwareLicensingService) |
            Invoke-CimMethod -MethodName RefreshLicenseStatus -ErrorAction SilentlyContinue
        Start-Process -FilePath "cscript" `
            -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" `
            -NoNewWindow -Wait
        $final = Get-ActivationStatus
        if ($final.IsActivated) { Write-Verbose "WINDOWS TERAKTIVASI PERMANEN!"; return $true }
        else { Write-Error "Proses selesai tapi status belum aktif. Cek koneksi internet."; return $false }
    } catch {
        Write-Error "Gagal aktivasi online: $($_.Exception.Message)"
        return $false
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-KMSActivation {
    Write-Verbose "Memulai KMS Activation..."
    $kmsServer = "kms8.msguides.com"
    try {
        $svc = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
        $svc | Invoke-CimMethod -MethodName SetKeyManagementServiceMachine -Arguments @{Name=$kmsServer} -ErrorAction Stop
        Write-Verbose "Server KMS diatur: $kmsServer"
        Start-Process -FilePath "cscript" `
            -ArgumentList "//nologo $env:SystemRoot\system32\slmgr.vbs /ato" `
            -NoNewWindow -Wait
        $final = Get-ActivationStatus
        if ($final.IsActivated) { Write-Verbose "WINDOWS SERVER TERAKTIVASI VIA KMS!"; return $true }
        else { Write-Error "KMS aktivasi gagal. Server mungkin sibuk."; return $false }
    } catch {
        Write-Error "KMS error: $($_.Exception.Message)"
        return $false
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
        } catch {
            Write-Error "Gagal daftar product key: $($_.Exception.Message)"
            return $false
        }

        if ($method -eq "HWID") { return Invoke-HWIDActivation }
        else { return Invoke-KMSActivation }
    }
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
                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
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
                    <Grid Margin="0,0,0,4">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBlock Text="Beban CPU" FontSize="11" Foreground="#AAAAAA"/>
                        <TextBlock Name="LblCpuVal" Grid.Column="1" Text="0%" FontSize="11" FontWeight="Bold" Foreground="#0078D4"/>
                    </Grid>
                    <ProgressBar Name="ProgCpu" Height="4" Value="0" Maximum="100" Background="#333333" Foreground="#0078D4" BorderThickness="0"/>
                    <Grid Margin="0,12,0,4">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
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
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Dashboard Utama" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Pantau status sistem dan lakukan optimalisasi cepat dengan sekali klik." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
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
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="180"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center">
                                        <TextBlock Text="&#x2B50; Optimalisasi Sekali Klik (Quick Boost)" FontSize="16" FontWeight="Bold" Foreground="#F7A22D"/>
                                        <TextBlock Text="Membuat Restore Point otomatis, membersihkan file temp, dan mengaktifkan Ultimate Performance." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,5,15,0"/>
                                    </StackPanel>
                                    <Button Name="BtnQuickBoost" Grid.Column="1" Style="{StaticResource AccentButton}" Content="Jalankan Boost" VerticalAlignment="Center" Height="40"/>
                                </Grid>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>
                <!-- TAB 2: OPTIMIZER -->
                <Grid Name="PanelOptimizer" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Modul Optimizer" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Kelola update, tingkatkan kinerja daya, dan bersihkan file sampah." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="280"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="Kontrol Windows Update" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Matikan auto-update atau aktifkan kembali kapan saja." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Right">
                                        <Button Name="BtnDisableWU" Style="{StaticResource ActionButton}" Content="Nonaktifkan Update" Width="135" Margin="0,0,10,0"/>
                                        <Button Name="BtnEnableWU"  Style="{StaticResource ActionButton}" Content="Aktifkan Update" Width="135"/>
                                    </StackPanel>
                                </Grid>
                            </Border>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
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
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="Buat System Restore Point" FontSize="15" FontWeight="Bold"/>
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
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Display &amp; HDMI Fix" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Perbaiki masalah output layar, HDMI tidak terdeteksi, atau crash driver grafis." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="Reset Driver Grafis" FontSize="15" FontWeight="Bold"/>
                                        <TextBlock Text="Mematikan dan menghidupkan kembali display adapter. Berguna jika layar freeze atau berkedip." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnResetGpu" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Reset Driver Grafis" VerticalAlignment="Center"/>
                                </Grid>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
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
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Keamanan &amp; Aplikasi (Bloatware)" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Jalankan scan virus atau pilih aplikasi bawaan Windows yang ingin dihapus." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="280"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <Border Grid.Column="0" Style="{StaticResource CardBorder}" Margin="0,0,10,15">
                            <StackPanel>
                                <TextBlock Text="Windows Defender Scan" FontSize="15" FontWeight="Bold"/>
                                <TextBlock Text="Jalankan scan virus cepat untuk memastikan sistem bersih dari ancaman aktif." FontSize="12" Foreground="#888888" TextWrapping="Wrap" Margin="0,5,0,20"/>
                                <Button Name="BtnDefenderScan" Style="{StaticResource ActionButton}" Content="Mulai Quick Scan" HorizontalAlignment="Left"/>
                            </StackPanel>
                        </Border>
                        <Border Grid.Column="1" Style="{StaticResource CardBorder}" Margin="10,0,0,15" Padding="15">
                            <Grid>
                                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                <Grid Grid.Row="0" Margin="0,0,0,10">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBlock Text="Pilih Bloatware untuk Dihapus:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/>
                                    <Button Name="BtnScanBloatware" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Scan Terinstal" FontSize="11" Padding="8,4,8,4"/>
                                </Grid>
                                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,0,0,10">
                                    <StackPanel Name="StackBloatware" Margin="5,0,5,0"/>
                                </ScrollViewer>
                                <Grid Grid.Row="2">
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                                    <TextBlock Name="LblBloatwareCount" Text="Gunakan 'Scan Terinstal' terlebih dahulu." FontSize="11" Foreground="#888888" VerticalAlignment="Center"/>
                                    <Button Name="BtnUninstallBloatware" Grid.Column="1" Style="{StaticResource ActionButton}" Content="Hapus Aplikasi Terpilih" FontWeight="SemiBold"/>
                                </Grid>
                            </Grid>
                        </Border>
                    </Grid>
                </Grid>
                <!-- TAB 5: ACTIVATION -->
                <Grid Name="PanelActivation" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Aktivasi Windows Permanent" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Aktifkan Windows secara permanen dengan Lisensi Digital (HWID) resmi Microsoft." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
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
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
                                    <StackPanel VerticalAlignment="Center" Margin="0,0,15,0">
                                        <TextBlock Text="&#x26A1; Jalankan Aktivasi Otomatis (1-Klik)" FontSize="16" FontWeight="Bold" Foreground="#52C452"/>
                                        <TextBlock Text="Mendaftarkan Generic Key Microsoft resmi, mengunduh gatherosstate.exe, menghasilkan GenuineTicket.xml, dan memicu pendaftaran Lisensi Digital permanen." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,5,0,0"/>
                                    </StackPanel>
                                    <Button Name="BtnStartActivation" Grid.Column="1" Style="{StaticResource AccentButton}" Background="#107C41" BorderBrush="#0B592E" Content="Aktifkan Sekarang" VerticalAlignment="Center" Height="40"/>
                                </Grid>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="&#x2139;&#xFE0F; Tentang Metode Aktivasi HWID &amp; KMS" FontSize="13" FontWeight="Bold" Margin="0,0,0,5"/>
                                    <TextBlock Text="&#x2022; HWID: Lisensi digital permanen terikat hardware motherboard. Setelah aktif, install ulang Windows tidak perlu aktivasi ulang." FontSize="11.5" Foreground="#888888" TextWrapping="Wrap" Margin="0,2,0,2"/>
                                    <TextBlock Text="&#x2022; KMS: Fallback untuk Windows Server. Aktif 180 hari, dapat diperbarui otomatis." FontSize="11.5" Foreground="#888888" TextWrapping="Wrap" Margin="0,2,0,2"/>
                                </StackPanel>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>
                <!-- TAB 6: ABOUT -->
                <Grid Name="PanelAbout" Visibility="Collapsed">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Margin="0,0,0,20">
                        <TextBlock Text="Tentang &amp; Bantuan" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Informasi mengenai aplikasi dan panduan singkat penggunaan." FontSize="13" Foreground="#888888" Margin="0,2,0,0"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                        <StackPanel>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Windows All-in-One Utility v1.1.0" FontSize="15" FontWeight="Bold" Foreground="#0078D4"/>
                                    <TextBlock Text="Aplikasi open-source untuk mengoptimalkan Windows 10/11, mengatasi error HDMI, membersihkan disk, dan membuang bloatware." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,10,0,10"/>
                                    <TextBlock Text="Lisensi: MIT (Bebas digunakan dan dimodifikasi)" FontSize="12" Foreground="#888888"/>
                                </StackPanel>
                            </Border>
                            <Border Style="{StaticResource CardBorder}">
                                <StackPanel>
                                    <TextBlock Text="Panduan Singkat" FontSize="15" FontWeight="Bold" Margin="0,0,0,8"/>
                                    <TextBlock Text="&#x2022; Selalu buat Restore Point sebelum tweak besar." FontSize="12" Foreground="#CCCCCC" Margin="0,2,0,2"/>
                                    <TextBlock Text="&#x2022; Antivirus mungkin menandai utilitas ini karena modifikasi registry/service - ini normal." FontSize="12" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,2,0,2"/>
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
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,5">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
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
$xamlContent.SelectNodes("//*[@Name]") | ForEach-Object {
    Set-Variable -Name $_.Name -Value $Window.FindName($_.Name) -Scope Script
}

# ============================
# 9. UI HELPERS
# ============================
$brushConverter  = New-Object System.Windows.Media.BrushConverter
$activeBg        = $brushConverter.ConvertFromString("#2B2B2B")
$activeBorder    = $brushConverter.ConvertFromString("#0078D4")
$transparentBrush = [System.Windows.Media.Brushes]::Transparent

$panels     = @($PanelDashboard,$PanelOptimizer,$PanelDisplayFix,$PanelSecurityApps,$PanelActivation,$PanelAbout)
$tabButtons = @($BtnTabDashboard,$BtnTabOptimizer,$BtnTabDisplayFix,$BtnTabSecurityApps,$BtnTabActivation,$BtnTabAbout)

function Switch-Tab ($index) {
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

$os = Get-CimInstance Win32_OperatingSystem
$LblOsName.Text    = $os.Caption
$LblOsVersion.Text = "Build: $($os.Version) ($($os.OSArchitecture))"

$syncHash = [hashtable]::Synchronized(@{
    Window     = $Window
    TxtConsole = $TxtConsole
    LblStatus  = $LblStatus
})

function Write-ToConsole ($Message, $Level = "Info") {
    $ts = Get-Date -Format "HH:mm:ss"
    $Window.Dispatcher.Invoke([Action]{
        $TxtConsole.AppendText("[$ts] [$Level] $Message`r`n")
        $TxtConsole.ScrollToEnd()
        $LblStatus.Text = "Status: $Message"
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
#     Uses InitialSessionState to properly share functions with runspaces
# ============================
$script:RunspaceFunctionNames = @(
    'Set-RestorePoint','Disable-WindowsUpdate','Enable-WindowsUpdate',
    'Clear-TempFiles','Optimize-PowerPlan','Reset-GraphicsStack','Clean-GraphicsRegistry',
    'Start-DefenderScan','Get-BloatwareStatus','Remove-Bloatware',
    'Get-ActivationStatus','Start-WindowsActivation','Invoke-HWIDActivation','Invoke-KMSActivation'
)

function New-TaskRunspace {
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

    # Import all module functions into the runspace
    foreach ($name in $script:RunspaceFunctionNames) {
        $fn = Get-Item "Function:\$name" -ErrorAction SilentlyContinue
        if ($fn) {
            $entry = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($name, $fn.Definition)
            $iss.Commands.Add($entry)
        }
    }

    # Import global variables (BloatwareMap, KeyDatabase, syncHash)
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

    # Inject Write-Log and Run-CommandWithStreaming helpers into the runspace
    $ps.AddScript({
        function Write-Log ($msg, $lvl = "Info") {
            $syncHash.Window.Dispatcher.Invoke([Action]{
                $ts = Get-Date -Format "HH:mm:ss"
                $syncHash.TxtConsole.AppendText("[$ts] [$lvl] $msg`r`n")
                $syncHash.TxtConsole.ScrollToEnd()
                $syncHash.LblStatus.Text = "Status: $msg"
            })
        }
        function Run-CommandWithStreaming ([ScriptBlock]$cmd) {
            $out = & $cmd *>&1
            foreach ($item in $out) {
                if     ($item -is [System.Management.Automation.VerboseRecord])  { Write-Log $item.Message "Info"    }
                elseif ($item -is [System.Management.Automation.WarningRecord])  { Write-Log $item.Message "Warning" }
                elseif ($item -is [System.Management.Automation.ErrorRecord])    { Write-Log $item.Exception.Message "Error" }
                elseif ($item -is [string])                                       { Write-Log $item "Info" }
            }
        }
    }) | Out-Null
    $ps.Invoke() | Out-Null
    $ps.Commands.Clear()

    # Add the actual task
    $ps.AddScript($Task) | Out-Null
    foreach ($arg in $Arguments) { $ps.AddArgument($arg) | Out-Null }

    # Capture outer variables for the callback closure
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
                $brushConverter.ConvertFromString("#FFFFCC00")
            }
            $LblActMethod.Text = if ($act.Edition -like "*Server*") {
                "Metode: KMS Client Server (Auto)"
            } else {
                "Metode: Digital License (HWID)"
            }
        }
    } catch {
        Write-ToConsole "Gagal refresh status aktivasi: $($_.Exception.Message)" "Error"
    }
}

# ============================
# 12. EVENT BINDINGS
# ============================
$BtnQuickBoost.Add_Click({
    Write-ToConsole "Memulai Quick Boost..."
    Invoke-BackgroundTask -Task {
        Write-Log "Langkah 1: Membuat Restore Point..."
        Run-CommandWithStreaming { Set-RestorePoint -Verbose }
        Write-Log "Langkah 2: Mengaktifkan Ultimate Performance..."
        Run-CommandWithStreaming { Optimize-PowerPlan -Verbose }
        Write-Log "Langkah 3: Membersihkan file sementara..."
        Run-CommandWithStreaming { Clear-TempFiles -Verbose }
        Write-Log "Quick Boost selesai!" "Info"
    }
})

$BtnDisableWU.Add_Click({
    Write-ToConsole "Menonaktifkan Windows Update..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Disable-WindowsUpdate -Verbose }
    }
})

$BtnEnableWU.Add_Click({
    Write-ToConsole "Mengaktifkan Windows Update..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Enable-WindowsUpdate -Verbose }
    }
})

$BtnCleanTemp.Add_Click({
    Write-ToConsole "Membersihkan Temp Files..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Clear-TempFiles -Verbose }
    }
})

$BtnUltimatePower.Add_Click({
    Write-ToConsole "Mengaktifkan Ultimate Performance..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Optimize-PowerPlan -Verbose }
    }
})

$BtnCreateRestore.Add_Click({
    Write-ToConsole "Membuat System Restore Point..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Set-RestorePoint -Verbose }
    }
})

$BtnResetGpu.Add_Click({
    Write-ToConsole "Mereset driver grafis..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Reset-GraphicsStack -Verbose }
    }
})

$BtnClearDispCache.Add_Click({
    Write-ToConsole "Membersihkan cache registry monitor..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Clean-GraphicsRegistry -Verbose }
    }
})

$BtnDefenderScan.Add_Click({
    Write-ToConsole "Memulai Windows Defender Quick Scan..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Start-DefenderScan -Verbose }
    }
})

$BtnScanBloatware.Add_Click({
    Write-ToConsole "Memindai bloatware terinstal..."
    Invoke-BackgroundTask -Task {
        Write-Log "Mengambil daftar aplikasi terinstal..."
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
            $LblBloatwareCount.Text = "Tidak ditemukan bloatware terinstal. Sistem bersih!"
            Write-ToConsole "Scan selesai. Tidak ada bloatware." "Info"
        } else {
            $LblBloatwareCount.Text = "Ditemukan $count aplikasi bloatware."
            Write-ToConsole "Scan selesai. Ditemukan $count bloatware." "Info"
        }
    }
})

$BtnUninstallBloatware.Add_Click({
    $selected = [System.Collections.Generic.List[PSCustomObject]]::new()
    $StackBloatware.Children | Where-Object { $_.IsChecked } | ForEach-Object { $selected.Add($_.Tag) }
    if ($selected.Count -eq 0) {
        Write-ToConsole "Pilih setidaknya satu aplikasi terlebih dahulu." "Info"
        return
    }
    Write-ToConsole "Menghapus $($selected.Count) aplikasi terpilih..."
    $appsToPass = $selected.ToArray()
    Invoke-BackgroundTask -Task {
        param($apps)
        Write-Log "Memulai penghapusan $($apps.Count) aplikasi..."
        $r = Remove-Bloatware -AppsToUninstall $apps
        Write-Log "Penghapusan selesai. Berhasil: $($r.SuccessCount), Gagal: $($r.FailCount)"
    } -Arguments @(,$appsToPass) -OnComplete {
        Write-ToConsole "Penghapusan selesai. Memindai ulang..." "Info"
        $BtnScanBloatware.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
    }
})

$BtnStartActivation.Add_Click({
    Write-ToConsole "Memulai proses aktivasi Windows..."
    Invoke-BackgroundTask -Task {
        Run-CommandWithStreaming { Start-WindowsActivation -Verbose }
    } -OnComplete {
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
    Write-ToConsole "Aplikasi berhasil dimuat. Selamat menggunakan Windows All-in-One Utility!" "Info"
})
$Window.Add_Closed({ $timer.Stop() })

# ============================
# 14. SHOW WINDOW
# ============================
$Window.ShowDialog() | Out-Null

# Windows All-in-One Utility - Main Controller
# Pastikan dijalankan sebagai Administrator dan dalam mode STA (Single-Threaded Apartment)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSTA = [System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'

if (-not $isAdmin -or -not $isSTA) {
    $argsList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if (-not $isAdmin) {
        Write-Host "Memerlukan hak akses Administrator. Meluncurkan ulang..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList $argsList -Verb RunAs
    } else {
        Write-Host "Memerlukan mode STA. Meluncurkan ulang..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList $argsList
    }
    Exit
}

# Import Assemblies WPF
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

# Tentukan direktori kerja
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesDir = "$scriptDir/modules"

# Muat file XAML secara dinamis
[xml]$xamlContent = Get-Content -Path "$scriptDir/ui/MainView.xaml"
$reader = New-Object System.Xml.XmlNodeReader $xamlContent
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Map semua kontrol yang memiliki atribut Name ke variabel PowerShell
$xamlContent.SelectNodes("//*[@Name]") | ForEach-Object {
    Set-Variable -Name $_.Name -Value $Window.FindName($_.Name) -Scope Script
}

# Hubungkan modul agar main controller dapat merujuk ke data default jika dibutuhkan
Import-Module "$modulesDir/Optimizer.psm1" -Force
Import-Module "$modulesDir/DisplayFix.psm1" -Force
Import-Module "$modulesDir/Security.psm1" -Force
Import-Module "$modulesDir/Bloatware.psm1" -Force
Import-Module "$modulesDir/Activation.psm1" -Force

# Setup warna untuk Tab Aktif
$brushConverter = New-Object System.Windows.Media.BrushConverter
$activeBg = $brushConverter.ConvertFromString("#2B2B2B")
$activeBorder = $brushConverter.ConvertFromString("#0078D4")
$transparentBrush = [System.Windows.Media.Brushes]::Transparent

# Setup Tab Panels dan Buttons
$panels = @($PanelDashboard, $PanelOptimizer, $PanelDisplayFix, $PanelSecurityApps, $PanelActivation, $PanelAbout)
$tabButtons = @($BtnTabDashboard, $BtnTabOptimizer, $BtnTabDisplayFix, $BtnTabSecurityApps, $BtnTabActivation, $BtnTabAbout)

function Switch-Tab($index) {
    for ($i = 0; $i -lt $panels.Count; $i++) {
        if ($i -eq $index) {
            $panels[$i].Visibility = [System.Windows.Visibility]::Visible
            $tabButtons[$i].Background = $activeBg
            $tabButtons[$i].BorderBrush = $activeBorder
        } else {
            $panels[$i].Visibility = [System.Windows.Visibility]::Collapsed
            $tabButtons[$i].Background = $transparentBrush
            $tabButtons[$i].BorderBrush = $transparentBrush
        }
    }
}

# Daftarkan navigasi tab
$BtnTabDashboard.Add_Click({ Switch-Tab 0 })
$BtnTabOptimizer.Add_Click({ Switch-Tab 1 })
$BtnTabDisplayFix.Add_Click({ Switch-Tab 2 })
$BtnTabSecurityApps.Add_Click({ Switch-Tab 3 })
$BtnTabActivation.Add_Click({ Refresh-ActivationUI; Switch-Tab 4 })
$BtnTabAbout.Add_Click({ Switch-Tab 5 })

# Inisialisasi Tab Aktif
Switch-Tab 0

# Status awal dan info sistem
$os = Get-CimInstance Win32_OperatingSystem
$LblOsName.Text = $os.Caption
$LblOsVersion.Text = "Build: $($os.Version) ($($os.OSArchitecture))"

# Helper untuk menulis log konsol secara aman dari UI thread
function Write-ToConsole ($Message, $Level = "Info") {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = "[$timestamp] [$Level] "
    
    $Window.Dispatcher.Invoke([Action]{
        $TxtConsole.AppendText("$prefix$Message`r`n")
        $TxtConsole.ScrollToEnd()
        $LblStatus.Text = "Status: $Message"
    })
}

# Kelompok kontrol untuk dinonaktifkan saat proses background berjalan
function Set-ControlsEnabled ($enabled) {
    $Window.Dispatcher.Invoke([Action]{
        $BtnTabDashboard.IsEnabled = $enabled
        $BtnTabOptimizer.IsEnabled = $enabled
        $BtnTabDisplayFix.IsEnabled = $enabled
        $BtnTabSecurityApps.IsEnabled = $enabled
        $BtnTabActivation.IsEnabled = $enabled
        $BtnQuickBoost.IsEnabled = $enabled
        $BtnDisableWU.IsEnabled = $enabled
        $BtnEnableWU.IsEnabled = $enabled
        $BtnCleanTemp.IsEnabled = $enabled
        $BtnUltimatePower.IsEnabled = $enabled
        $BtnCreateRestore.IsEnabled = $enabled
        $BtnResetGpu.IsEnabled = $enabled
        $BtnClearDispCache.IsEnabled = $enabled
        $BtnDefenderScan.IsEnabled = $enabled
        $BtnScanBloatware.IsEnabled = $enabled
        $BtnUninstallBloatware.IsEnabled = $enabled
        $BtnStartActivation.IsEnabled = $enabled
    })
}

# Objek Sinkronisasi untuk Background Runspace
$syncHash = [hashtable]::Synchronized(@{
    Window = $Window
    TxtConsole = $TxtConsole
    LblStatus = $LblStatus
})

# Helper Eksekusi Background Runspace
function Invoke-BackgroundTask {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [Parameter(Mandatory = $false)]
        [ScriptBlock]$OnComplete = $null,
        [Parameter(Mandatory = $false)]
        [Object[]]$Arguments = @()
    )
    
    Set-ControlsEnabled $false
    $ProgressMain.IsIndeterminate = $true
    
    $ps = [PowerShell]::Create()
    $ps.AddScript($ScriptBlock) | Out-Null
    
    # Argumen default: 1 = syncHash, 2 = modulesDir
    $ps.AddArgument($syncHash) | Out-Null
    $ps.AddArgument($modulesDir) | Out-Null
    
    # Argumen kustom tambahan
    foreach ($arg in $Arguments) {
        $ps.AddArgument($arg) | Out-Null
    }
    
    $asyncResult = $ps.BeginInvoke({
        param($ar)
        $psInstance = $ar.AsyncState
        $res = $null
        try {
            $res = $psInstance.EndInvoke($ar)
        }
        catch {
            $syncHash.Window.Dispatcher.Invoke([Action]{
                $TxtConsole.AppendText("[ERROR] Runspace exception: $_`r`n")
            })
        }
        
        # Selesai, kembalikan ke UI thread
        $syncHash.Window.Dispatcher.Invoke([Action]{
            if ($OnComplete) {
                & $OnComplete $res
            }
            Set-ControlsEnabled $true
            $ProgressMain.IsIndeterminate = $false
            $ProgressMain.Value = 100
        })
        
        $psInstance.Dispose()
    }, $ps)
}

# Template ScriptBlock untuk background runspace
# Menyediakan fungsi Write-Log dan Run-Command di sisi runspace
$commonHeader = {
    param($sync, $modulesDir)
    
    function Write-Log ($msg, $lvl = "Info") {
        $sync.Window.Dispatcher.Invoke([Action]{
            $timestamp = Get-Date -Format "HH:mm:ss"
            $prefix = "[$timestamp] [$lvl] "
            $sync.TxtConsole.AppendText("$prefix$msg`r`n")
            $sync.TxtConsole.ScrollToEnd()
            $sync.LblStatus.Text = "Status: $msg"
        })
    }

    function Run-CommandWithStreaming {
        param([ScriptBlock]$cmd)
        $outputs = & $cmd *>&1
        foreach ($item in $outputs) {
            if ($item -is [System.Management.Automation.VerboseRecord]) {
                Write-Log $item.Message "Info"
            }
            elseif ($item -is [System.Management.Automation.WarningRecord]) {
                Write-Log $item.Message "Warning"
            }
            elseif ($item -is [System.Management.Automation.ErrorRecord]) {
                Write-Log $item.Exception.Message "Error"
            }
            elseif ($item -is [System.Management.Automation.InformationRecord]) {
                Write-Log $item.MessageData.ToString() "Info"
            }
            else {
                if ($item -is [string]) {
                    Write-Log $item "Info"
                }
            }
        }
    }
}

# Helper untuk menyegarkan status aktivasi di UI
function Refresh-ActivationUI {
    try {
        $act = Get-ActivationStatus
        if ($act) {
            $LblActOsName.Text = $act.Edition
            $LblActOsVersion.Text = "Build: $($act.Version)"
            $LblActStatus.Text = $act.Status
            
            if ($act.IsActivated) {
                $LblActStatus.Foreground = [System.Windows.Media.Brushes]::LimeGreen
            } else {
                $LblActStatus.Foreground = $brushConverter.ConvertFromString("#FFFFCC00")
            }
            
            if ($act.Edition -like "*Server*") {
                $LblActMethod.Text = "Metode: KMS Client Server (Auto)"
            } else {
                $LblActMethod.Text = "Metode: Digital License (HWID)"
            }
        }
    }
    catch {
        Write-ToConsole "Gagal memperbarui status aktivasi di UI: $_" "Error"
    }
}

# ================= KONEKSI TOMBOL & LOGIK =================

# 1. Quick Boost
$BtnQuickBoost.Add_Click({
    Write-ToConsole "Memulai Quick Boost (Optimalisasi Sekali Klik)..."
    
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Optimizer.psm1" -Force
        
        Write-Log "Langkah 1: Membuat Restore Point otomatis..."
        Run-CommandWithStreaming { Set-RestorePoint -Verbose }
        
        Write-Log "Langkah 2: Mengaktifkan mode Ultimate Performance..."
        Run-CommandWithStreaming { Optimize-PowerPlan -Verbose }
        
        Write-Log "Langkah 3: Membersihkan file sementara..."
        Run-CommandWithStreaming { Clear-TempFiles -Verbose }
        
        Write-Log "Quick Boost selesai!" "Success"
"@)
    
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 2. Disable Windows Update
$BtnDisableWU.Add_Click({
    Write-ToConsole "Menyiapkan proses penonaktifan Windows Update..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Optimizer.psm1" -Force
        Run-CommandWithStreaming { Disable-WindowsUpdate -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 3. Enable Windows Update
$BtnEnableWU.Add_Click({
    Write-ToConsole "Menyiapkan proses pengaktifan kembali Windows Update..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Optimizer.psm1" -Force
        Run-CommandWithStreaming { Enable-WindowsUpdate -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 4. Clean Temp Files
$BtnCleanTemp.Add_Click({
    Write-ToConsole "Menyiapkan pembersihan file-file sementara..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Optimizer.psm1" -Force
        Run-CommandWithStreaming { Clear-TempFiles -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 5. Ultimate Power Plan
$BtnUltimatePower.Add_Click({
    Write-ToConsole "Menyiapkan aktivasi Ultimate Performance..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Optimizer.psm1" -Force
        Run-CommandWithStreaming { Optimize-PowerPlan -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 6. Create Restore Point
$BtnCreateRestore.Add_Click({
    Write-ToConsole "Menyiapkan pembuatan System Restore Point..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Optimizer.psm1" -Force
        Run-CommandWithStreaming { Set-RestorePoint -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 7. Reset GPU
$BtnResetGpu.Add_Click({
    Write-ToConsole "Menyiapkan reset driver grafis..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/DisplayFix.psm1" -Force
        Run-CommandWithStreaming { Reset-GraphicsStack -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 8. Clear Display Registry Cache
$BtnClearDispCache.Add_Click({
    Write-ToConsole "Menyiapkan pembersihan cache monitor..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/DisplayFix.psm1" -Force
        Run-CommandWithStreaming { Clean-GraphicsRegistry -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 9. Defender Scan
$BtnDefenderScan.Add_Click({
    Write-ToConsole "Menyiapkan pemindaian virus cepat..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Security.psm1" -Force
        Run-CommandWithStreaming { Start-DefenderScan -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb
})

# 10. Scan Bloatware UWP & OneDrive
$BtnScanBloatware.Add_Click({
    Write-ToConsole "Memulai pemindaian bloatware sistem..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Bloatware.psm1" -Force
        # Jalankan pemindaian dan kembalikan objek list
        Get-BloatwareStatus
"@)
    Invoke-BackgroundTask -ScriptBlock $sb -OnComplete {
        param($results)
        
        $StackBloatware.Children.Clear()
        $installedCount = 0
        
        foreach ($app in $results) {
            if ($app.Installed) {
                $cb = New-Object System.Windows.Controls.CheckBox
                $cb.Content = "$($app.DisplayName) ($($app.Type))"
                $cb.Tag = $app
                $cb.Margin = "5,5,5,5"
                $cb.Foreground = [System.Windows.Media.Brushes]::White
                $cb.FontSize = 12
                $StackBloatware.Children.Add($cb)
                $installedCount++
            }
        }
        
        if ($installedCount -eq 0) {
            $LblBloatwareCount.Text = "Tidak ditemukan bloatware terinstal!"
            Write-ToConsole "Pemindaian bloatware selesai. Sistem bersih." "Success"
        } else {
            $LblBloatwareCount.Text = "Ditemukan $installedCount aplikasi bloatware terinstal."
            Write-ToConsole "Pemindaian bloatware selesai. Ditemukan $installedCount aplikasi terinstal." "Warning"
        }
    }
})

# 11. Uninstall Selected Bloatware
$BtnUninstallBloatware.Add_Click({
    $selectedApps = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($cb in $StackBloatware.Children) {
        if ($cb.IsChecked) {
            $selectedApps.Add($cb.Tag)
        }
    }
    
    if ($selectedApps.Count -eq 0) {
        Write-ToConsole "Silakan pilih setidaknya satu aplikasi untuk dihapus." "Warning"
        return
    }
    
    Write-ToConsole "Menyiapkan penghapusan $($selectedApps.Count) aplikasi terpilih..."
    
    # Karena kita ingin mempassing array ke runspace, kita menggunakan parameter kustom $Arguments
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        param(`$sync, `$modulesDir, `$apps)
        Import-Module "$modulesDir/Bloatware.psm1" -Force
        Run-CommandWithStreaming { Remove-Bloatware -AppsToUninstall `$apps -Verbose }
"@)
    
    Invoke-BackgroundTask -ScriptBlock $sb -Arguments @($selectedApps) -OnComplete {
        Write-ToConsole "Proses penghapusan selesai. Memindai ulang..." "Success"
        # Jalankan trigger klik tombol scan untuk refresh daftar
        $BtnScanBloatware.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
    }
})

# 12. Windows Activation
$BtnStartActivation.Add_Click({
    Write-ToConsole "Memulai proses aktivasi Windows..."
    $sb = [ScriptBlock]::Create($commonHeader.ToString() + @"
        Import-Module "$modulesDir/Activation.psm1" -Force
        Run-CommandWithStreaming { Start-WindowsActivation -Verbose }
"@)
    Invoke-BackgroundTask -ScriptBlock $sb -OnComplete {
        Refresh-ActivationUI
        Write-ToConsole "Proses aktivasi selesai." "Success"
    }
})

# ================= BACKGROUND WIDGET MONITOR TICK =================

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({
    try {
        # Update CPU load
        $cpuSample = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
        $cpuVal = 0
        if ($cpuSample) {
            $cpuVal = $cpuSample.PercentProcessorTime
        }
        $ProgCpu.Value = $cpuVal
        $LblCpuVal.Text = "$cpuVal%"
        
        # Update RAM Load
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($osInfo) {
            $total = $osInfo.TotalVisibleMemorySize
            $free = $osInfo.FreePhysicalMemory
            $used = $total - $free
            $ramPct = [Math]::Round(($used / $total) * 100, 0)
            
            $ProgRam.Value = $ramPct
            $LblRamVal.Text = "$ramPct%"
        }
    }
    catch {
        # Diabaikan agar tidak memunculkan dialog popup crash di UI
    }
})

# Mulai monitoring hardware saat window terbuka
$Window.Add_Loaded({
    $timer.Start()
    Refresh-ActivationUI
    Write-ToConsole "Aplikasi berhasil dimuat. Siap digunakan." "Success"
})

# Hentikan monitoring saat window ditutup
$Window.Add_Closed({
    $timer.Stop()
})

# Jalankan GUI
Write-ToConsole "Memulai Antarmuka Windows All-in-One Utility..."
$Window.ShowDialog() | Out-Null

# Windows All-in-One Utility - Bloatware Module

$global:BloatwareMap = [ordered]@{
    "Cortana"                            = "Microsoft.549981C3F5F10"
    "Xbox Suite & Overlay"               = "Microsoft.Xbox*"
    "Skype"                              = "Microsoft.SkypeApp"
    "Movies & TV (Zune Video)"           = "Microsoft.ZuneVideo"
    "Groove Music (Zune Music)"          = "Microsoft.ZuneMusic"
    "Microsoft Office Hub"               = "Microsoft.MicrosoftOfficeHub"
    "Solitaire Collection"               = "Microsoft.MicrosoftSolitaireCollection"
    "Feedback Hub"                       = "Microsoft.WindowsFeedbackHub"
    "Mixed Reality Portal"               = "Microsoft.MixedReality.Portal"
    "Sticky Notes"                       = "Microsoft.MicrosoftStickyNotes"
    "Windows Maps"                       = "Microsoft.WindowsMaps"
    "Phone Link (Your Phone)"            = "Microsoft.YourPhone"
    "MSN Weather"                        = "Microsoft.BingWeather"
    "MSN News"                           = "Microsoft.BingNews"
    "MSN Sports"                         = "Microsoft.BingSports"
    "MSN Finance"                        = "Microsoft.BingFinance"
    "Paint 3D"                           = "Microsoft.MSPaint"
    "3D Viewer"                          = "Microsoft.Microsoft3DViewer"
    "Windows People"                     = "Microsoft.People"
    "OneNote"                            = "Microsoft.Office.OneNote"
    "Get Help"                           = "Microsoft.GetHelp"
    "Mail & Calendar"                    = "Microsoft.windowscommunicationsapps"
    "Clipchamp"                          = "Clipchamp.Clipchamp"
}

function Get-BloatwareStatus {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Memindai daftar bloatware terinstal..."
        try {
            # Ambil semua paket AppX terinstal
            $installedPackages = Get-AppxPackage -AllUsers -ErrorAction Stop | Select-Object -ExpandProperty Name
            
            $results = [System.Collections.Generic.List[PSCustomObject]]::new()
            
            # 1. Cek aplikasi UWP dari map
            foreach ($key in $global:BloatwareMap.Keys) {
                $pattern = $global:BloatwareMap[$key]
                $installed = $false
                
                foreach ($pkg in $installedPackages) {
                    if ($pkg -like $pattern) {
                        $installed = $true
                        break
                    }
                }
                
                $results.Add([PSCustomObject]@{
                    DisplayName = $key
                    PackageName = $pattern
                    Type        = "UWP"
                    Installed   = $installed
                })
            }
            
            # 2. Cek Microsoft OneDrive
            $oneDriveInstalled = $false
            if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -or Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
                # Cek registry atau folder untuk melihat apakah diinstal per user atau sistem
                if (Get-Process "OneDrive" -ErrorAction SilentlyContinue) {
                    $oneDriveInstalled = $true
                }
                elseif (Test-Path "$env:LocalAppData\Microsoft\OneDrive\OneDrive.exe") {
                    $oneDriveInstalled = $true
                }
                elseif (Test-Path "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe") {
                    $oneDriveInstalled = $true
                }
                elseif (Test-Path "$env:ProgramFiles(x86)\Microsoft OneDrive\OneDrive.exe") {
                    $oneDriveInstalled = $true
                }
            }
            
            $results.Add([PSCustomObject]@{
                DisplayName = "Microsoft OneDrive"
                PackageName = "OneDrive"
                Type        = "Win32"
                Installed   = $oneDriveInstalled
            })
            
            return $results
        }
        catch {
            Write-Error "Gagal mendapatkan daftar bloatware: $_"
            return @()
        }
    }
}

function Remove-Bloatware {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$AppsToUninstall
    )
    process {
        $successCount = 0
        $failCount = 0
        
        foreach ($app in $AppsToUninstall) {
            Write-Verbose "Mencoba menghapus: $($app.DisplayName)..."
            
            if ($app.PackageName -eq "OneDrive") {
                # Uninstall OneDrive
                try {
                    Write-Verbose "Menghentikan proses OneDrive..."
                    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    
                    $uninstallPath64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
                    $uninstallPath32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
                    
                    if (Test-Path $uninstallPath64) {
                        Write-Verbose "Menjalankan uninstaller OneDrive 64-bit..."
                        $proc = Start-Process -FilePath $uninstallPath64 -ArgumentList "/uninstall" -NoNewWindow -PassThru -Wait
                    }
                    elseif (Test-Path $uninstallPath32) {
                        Write-Verbose "Menjalankan uninstaller OneDrive 32-bit..."
                        $proc = Start-Process -FilePath $uninstallPath32 -ArgumentList "/uninstall" -NoNewWindow -PassThru -Wait
                    }
                    
                    # Bersihkan file sisa OneDrive
                    Remove-Item -Path "$env:LocalAppData\Microsoft\OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
                    Remove-Item -Path "$env:ProgramData\Microsoft\OneDrive" -Force -Recurse -ErrorAction SilentlyContinue
                    
                    Write-Verbose "OneDrive berhasil di-uninstall."
                    $successCount++
                }
                catch {
                    Write-Error "Gagal menghapus OneDrive: $_"
                    $failCount++
                }
            }
            else {
                # Uninstall UWP App
                try {
                    # Cari paket lengkapnya (karena pattern menggunakan wildcard)
                    $packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $app.PackageName }
                    if ($packages) {
                        foreach ($pkg in $packages) {
                            Write-Verbose "Menghapus paket: $($pkg.PackageFullName)"
                            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                        }
                        Write-Verbose "Aplikasi UWP $($app.DisplayName) berhasil dihapus."
                        $successCount++
                    }
                    else {
                        Write-Verbose "Aplikasi UWP $($app.DisplayName) tidak ditemukan atau sudah dihapus."
                        $successCount++
                    }
                }
                catch {
                    Write-Error "Gagal menghapus UWP $($app.DisplayName): $_"
                    $failCount++
                }
            }
        }
        
        Write-Verbose "Penghapusan Bloatware selesai. Berhasil: $successCount, Gagal: $failCount."
        return [PSCustomObject]@{
            SuccessCount = $successCount
            FailCount    = $failCount
        }
    }
}

Export-ModuleMember -Function Get-BloatwareStatus, Remove-Bloatware

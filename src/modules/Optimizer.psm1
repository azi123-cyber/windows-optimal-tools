# Windows All-in-One Utility - Optimizer Module

function Set-RestorePoint {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Memulai pembuatan Restore Point..."
        try {
            # Pastikan System Restore aktif untuk drive C:
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            
            # Buat Restore Point
            Checkpoint-Computer -Description "Win11Opt_BeforeTweak" -RestorePointType MODIFY_SETTINGS -Confirm:$false
            Write-Verbose "System Restore Point 'Win11Opt_BeforeTweak' berhasil dibuat!"
            return $true
        }
        catch {
            Write-Error "Gagal membuat Restore Point: $_"
            return $false
        }
    }
}

function Disable-WindowsUpdate {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Menonaktifkan Windows Update..."
        $services = @("wuauserv", "UsoSvc", "bits")
        foreach ($service in $services) {
            try {
                if (Get-Service $service -ErrorAction SilentlyContinue) {
                    Write-Verbose "Menghentikan layanan $service..."
                    Stop-Service -Name $service -Force -ErrorAction Stop
                    Set-Service -Name $service -StartupType Disabled -ErrorAction Stop
                }
            }
            catch {
                Write-Error "Gagal menghentikan layanan $service: $_"
            }
        }

        # Registry Tweaks untuk mematikan auto update
        $registryPaths = @(
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate",
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        )

        foreach ($path in $registryPaths) {
            if (!(Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }
        }

        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Verbose "Registry tweak NoAutoUpdate diatur ke 1."
            return $true
        }
        catch {
            Write-Error "Gagal mengatur registry Windows Update: $_"
            return $false
        }
    }
}

function Enable-WindowsUpdate {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Mengaktifkan kembali Windows Update..."
        
        # Hapus registry tweak auto update jika ada
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (Test-Path $path) {
            try {
                Remove-ItemProperty -Path $path -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "Gagal menghapus registry NoAutoUpdate, mencoba menimpa ke 0..."
                Set-ItemProperty -Path $path -Name "NoAutoUpdate" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        }

        $services = @("wuauserv", "UsoSvc", "bits")
        foreach ($service in $services) {
            try {
                if (Get-Service $service -ErrorAction SilentlyContinue) {
                    Write-Verbose "Mengaktifkan layanan $service..."
                    Set-Service -Name $service -StartupType Automatic -ErrorAction Stop
                    Start-Service -Name $service -ErrorAction Stop
                }
            }
            catch {
                Write-Error "Gagal memulai layanan $service: $_"
            }
        }
        Write-Verbose "Windows Update berhasil diaktifkan kembali."
        return $true
    }
}

function Clear-TempFiles {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Membersihkan file-file sementara (Temp files)..."
        $tempPaths = @(
            "$env:SystemRoot\Temp\*",
            "$env:TEMP\*",
            "$env:SystemRoot\Prefetch\*"
        )

        $deletedCount = 0
        $freedSpaceBytes = 0

        foreach ($path in $tempPaths) {
            Write-Verbose "Memproses: $path"
            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    $size = $file.Length
                    Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction Stop
                    $deletedCount++
                    $freedSpaceBytes += $size
                }
                catch {
                    # File sedang dikunci oleh sistem/aplikasi lain, abaikan
                    continue
                }
            }
            # Hapus folder kosong
            $folders = Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object -Property FullName -Descending
            foreach ($folder in $folders) {
                try {
                    Remove-Item -Path $folder.FullName -Force -ErrorAction SilentlyContinue
                }
                catch {}
            }
        }

        $freedSpaceMB = [Math]::Round($freedSpaceBytes / 1MB, 2)
        Write-Verbose "Pembersihan selesai! Menghapus $deletedCount file. Ruang dibebaskan: $freedSpaceMB MB."
        return [PSCustomObject]@{
            Success = $true
            DeletedCount = $deletedCount
            FreedSpaceMB = $freedSpaceMB
        }
    }
}

function Optimize-PowerPlan {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Mengatur Power Plan ke Ultimate Performance..."
        try {
            # Ultimate Performance GUID
            $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            
            # Cek apakah skema Ultimate Performance sudah terinstall
            $plans = powercfg -list
            if ($plans -notmatch $ultimateGuid) {
                Write-Verbose "Menduplikasi skema Ultimate Performance..."
                powercfg -duplicatescheme $ultimateGuid | Out-Null
            }
            
            # Aktifkan skema Ultimate Performance
            powercfg -setactive $ultimateGuid
            Write-Verbose "Power Plan berhasil diubah ke Ultimate Performance."
            return $true
        }
        catch {
            Write-Error "Gagal mengubah Power Plan: $_"
            return $false
        }
    }
}

Export-ModuleMember -Function Set-RestorePoint, Disable-WindowsUpdate, Enable-WindowsUpdate, Clear-TempFiles, Optimize-PowerPlan

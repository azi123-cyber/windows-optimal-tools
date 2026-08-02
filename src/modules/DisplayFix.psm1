# Windows All-in-One Utility - Display Fix Module

function Reset-GraphicsStack {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Mereset Driver Grafis (Simulasi Win + Ctrl + Shift + B)..."
        $success = $false
        
        try {
            # Cara 1: Dapatkan semua Display Adapter dan restart (Disable lalu Enable)
            $adapters = Get-PnpDevice -ClassName Display -Status OK -ErrorAction Stop
            foreach ($adapter in $adapters) {
                Write-Verbose "Mereset adapter: $($adapter.FriendlyName)"
                Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction Stop
                Start-Sleep -Milliseconds 500
                Enable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction Stop
                Write-Verbose "Adapter $($adapter.FriendlyName) berhasil di-restart."
            }
            $success = $true
        }
        catch {
            Write-Warning "Metode PnpDevice gagal: $_. Mencoba merestart proses DWM..."
        }

        try {
            # Cara 2: Restart Desktop Window Manager (DWM) jika display adapter restart gagal/tidak cukup
            Write-Verbose "Menghentikan proses Desktop Window Manager (dwm) untuk memicu auto-restart..."
            # DWM akan otomatis dijalankan kembali oleh Windows Winlogon
            Stop-Process -Name dwm -Force -ErrorAction Stop
            Write-Verbose "DWM berhasil dipicu untuk restart."
            $success = $true
        }
        catch {
            Write-Error "Gagal merestart DWM: $_"
        }

        return $success
    }
}

function Clean-GraphicsRegistry {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Membersihkan cache konfigurasi monitor di registry..."
        $paths = @(
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Connectivity",
            "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\ScaleFactors"
        )
        
        $clearedCount = 0
        foreach ($path in $paths) {
            if (Test-Path $path) {
                try {
                    # Hapus semua subkey di dalamnya tapi biarkan root path tetap ada
                    $subKeys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                    foreach ($subKey in $subKeys) {
                        Remove-Item -Path $subKey.PSPath -Recurse -Force -ErrorAction Stop
                        $clearedCount++
                    }
                    Write-Verbose "Berhasil membersihkan subkey di: $path"
                }
                catch {
                    Write-Error "Gagal membersihkan $path: $_"
                }
            }
        }
        
        Write-Verbose "Pembersihan cache monitor selesai. $clearedCount entri dihapus."
        Write-Verbose "Catatan: Hubungkan kembali kabel HDMI/DisplayPort Anda agar Windows mendeteksi ulang layar."
        return ($clearedCount -gt 0)
    }
}

Export-ModuleMember -Function Reset-GraphicsStack, Clean-GraphicsRegistry

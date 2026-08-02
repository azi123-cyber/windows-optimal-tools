# Windows All-in-One Utility - Security Module

function Start-DefenderScan {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Memulai pemindaian virus cepat (Quick Scan) dengan Windows Defender..."
        try {
            # Gunakan Cmdlet bawaan PowerShell jika tersedia
            if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
                Write-Verbose "Menggunakan cmdlet Start-MpScan..."
                Start-MpScan -ScanType QuickScan -ErrorAction Stop
                Write-Verbose "Pemindaian Defender selesai!"
                return $true
            }
            else {
                # Jalankan lewat CLI MpCmdRun.exe jika cmdlet tidak tersedia
                $paths = @(
                    "$env:ProgramFiles\Windows Defender\MpCmdRun.exe",
                    "$env:ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe"
                )
                $exe = $null
                foreach ($p in $paths) {
                    $resolved = Resolve-Path $p -ErrorAction SilentlyContinue
                    if ($resolved) {
                        # Ambil yang terbaru jika ada beberapa folder platform
                        $exe = $resolved[-1].Path
                        break
                    }
                }
                
                if ($exe) {
                    Write-Verbose "Menjalankan CLI Defender dari: $exe"
                    $process = Start-Process -FilePath $exe -ArgumentList "-Scan -ScanType 1" -NoNewWindow -PassThru -Wait
                    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 2) {
                        # Exit code 0 = No threats, 2 = Threats detected and cleaned/action taken (or just completed)
                        Write-Verbose "Pemindaian Defender CLI selesai."
                        return $true
                    }
                    else {
                        throw "Proses MpCmdRun keluar dengan kode error: $($process.ExitCode)"
                    }
                }
                else {
                    throw "Windows Defender CLI tidak ditemukan di sistem."
                }
            }
        }
        catch {
            Write-Error "Gagal menjalankan scan virus: $_"
            return $false
        }
    }
}

Export-ModuleMember -Function Start-DefenderScan

# Windows All-in-One Utility (Win11Opt)

A modern, high-performance, single-window system utility for Windows 10/11 designed using WPF (Windows Presentation Foundation) with a clean Dark Mode interface. 

To ensure the application remains perfectly responsive and doesn't freeze during heavy operations (like virus scans or deleting temp files), it utilizes **PowerShell Runspaces** for background multi-threading.

---

## 🛠️ Fitur Utama

- **📊 Dashboard Utama**: Menampilkan informasi sistem OS real-time beserta beban CPU dan RAM.
- **⚡ System Optimizer**:
  - **Quick Boost**: Sekali klik untuk membuat System Restore Point, membersihkan temp files, dan mengaktifkan Ultimate Performance.
  - **Windows Update Control**: Menonaktifkan auto-update agar tidak mengganggu aktivitas, atau mengaktifkannya kembali secara standar.
  - **Cleanup Temp Files**: Membersihkan direktori System Temp, User Temp, dan Prefetch.
  - **Ultimate Performance Plan**: Mengaktifkan rencana daya tersembunyi berkinerja tinggi.
  - **System Restore Point**: Membuat checkpoint backup sistem secara otomatis maupun manual.
- **🗝️ Aktivasi Windows Permanent**:
  - **HWID (Digital License)**: Aktivasi lisensi digital permanen otomatis 1-klik untuk sistem Windows 10/11 Client (Home, Pro, Education, Enterprise) yang terikat langsung pada perangkat keras (motherboard).
  - **KMS Client Fallback**: Konfigurasi server KMS client otomatis untuk Windows Server (Standard & Datacenter) yang tidak mendukung aktivasi HWID.
- **🖥️ Display & HDMI Fix**:
  - **Reset Graphics Driver**: Merestart Display Adapter (simulasi pintasan `Win + Ctrl + Shift + B`) dan merestart Desktop Window Manager (DWM).
  - **HDMI Cache Clear**: Menghapus cache topo-monitor lawas di registry guna mendeteksi ulang monitor eksternal/HDMI.
- **🛡️ Keamanan & Aplikasi**:
  - **Defender Quick Scan**: Melakukan pemindaian cepat antivirus bawaan Windows Defender.
  - **Bloatware Picker**: Memindai dan menampilkan daftar checkbox aplikasi bawaan (Cortana, Xbox Suite, Skype, OneDrive, dll) untuk di-uninstall secara kustom.

---

## 🚀 Cara Menjalankan Instan (1 Baris Perintah)

Anda dapat mengunduh dan menjalankan aplikasi ini langsung dari PowerShell tanpa perlu mengunduh file satu per satu secara manual. 

Buka **PowerShell sebagai Administrator** dan jalankan perintah berikut:

```powershell
iwr -useb https://raw.githubusercontent.com/USERNAME_KAMU/WIN11OPT/main/install.ps1 | iex
```

*(Catatan: Ubah `USERNAME_KAMU` dengan nama username GitHub tempat Anda menyimpan repository ini).*

---

## 💻 Penggunaan Lokal (Development)

Untuk memodifikasi atau menjalankan secara lokal, clone repository ini dan jalankan controller utama:

1. Clone repository:
   ```bash
   git clone https://github.com/USERNAME_KAMU/WIN11OPT.git
   cd WIN11OPT
   ```
2. Jalankan script utama di Windows (dengan hak Administrator):
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\src\Win11Opt.ps1
   ```

---

## 📦 Mengkompilasi Menjadi File .exe

Jika Anda ingin membungkus seluruh script menjadi file eksekusi `.exe` yang terisolasi:

1. Buka PowerShell sebagai Administrator di folder proyek.
2. Jalankan script kompilasi:
   ```powershell
   .\build\Compile-Exe.ps1
   ```
3. Output akan terbuat di folder `build/Win11Opt.exe`.
4. **Penting**: Salin atau sertakan folder `ui/` dan `modules/` di sebelah `Win11Opt.exe` agar aplikasi dapat memuat antarmuka dan logikanya.

---

## ⚠️ Informasi Penting: Deteksi Antivirus (False Positive)

Karena aplikasi ini berinteraksi langsung dengan sistem operasi tingkat tinggi (seperti menghentikan layanan Windows Update, menghapus file system cache, merestart display adapter, dan memodifikasi registry), **Windows Defender atau Antivirus pihak ketiga mungkin akan mendeteksinya sebagai potensi ancaman (False Positive).**

**Mengapa ini terjadi?**
- Kompiler script-ke-exe (`PS2EXE`) sering kali dicurigai oleh mesin pembaca heuristik antivirus karena teknik pembungkusannya (wrapping).
- Aktivitas memodifikasi layanan Windows (`wuauserv`, `UsoSvc`) dan menulis ke registry `HKLM` dianggap mencurigakan bagi aplikasi tidak dikenal.

**Solusi:**
- Seluruh kode proyek ini bersifat **100% open-source**. Anda dapat memeriksa isi script pada folder `src/` untuk membuktikan tidak ada kode berbahaya.
- Jika Windows Defender memblokir aplikasi saat dijalankan, tambahkan pengecualian (Exclusion) pada folder tempat Anda mengekstrak atau menginstal aplikasi ini (`C:\Win11Opt` jika menggunakan web installer).

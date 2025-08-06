#!/bin/bash

# ===================================================================================
# Script Cerdas untuk Mengizinkan Login Root & Otentikasi Password di SSH (v2.0)
#
# FITUR:
# - Hanya berjalan jika menggunakan sudo (root).
# - Meminta konfirmasi sebelum eksekusi.
# - Membuat backup dengan timestamp (contoh: sshd_config.bak.2025-08-06_10-30-00).
# - Idempotent: Hanya mengubah dan me-restart service jika diperlukan.
# - Output berwarna untuk kemudahan membaca.
#
# Dijalankan via Gist:
# sudo bash <(curl -sL https://gist.githubusercontent.com/...)
# ===================================================================================

# --- Definisi Warna ---
MERAH='\033[0;31m'
HIJAU='\033[0;32m'
KUNING='\033[1;33m'
NC='\033[0m' # No Color

# --- Fungsi untuk Mencetak Pesan ---
info() { echo -e "${HIJAU}[INFO]${NC} $1"; }
peringatan() { echo -e "${KUNING}[PERINGATAN]${NC} $1"; }
error() { echo -e "${MERAH}[ERROR]${NC} $1"; }

# 1. Pengecekan Hak Akses Root
if [[ $EUID -ne 0 ]]; then
   error "Script ini harus dijalankan sebagai root atau dengan sudo."
   exit 1
fi

# 2. Tampilkan Peringatan dan Minta Konfirmasi
clear
peringatan "Script ini akan mengubah konfigurasi SSH untuk mengizinkan login root dengan password."
peringatan "Ini adalah RISIKO KEAMANAN yang signifikan dan tidak disarankan untuk server produksi."
echo ""
read -p "Apakah Anda benar-benar yakin ingin melanjutkan? (y/N): " konfirmasi
if [[ ! "$konfirmasi" =~ ^[Yy]$ ]]; then
    info "Operasi dibatalkan oleh pengguna."
    exit 0
fi

# --- Mulai Proses Konfigurasi ---
CONFIG_FILE="/etc/ssh/sshd_config"
PERUBAHAN_DIBUAT=0

info "Memulai konfigurasi SSH..."

# Cek apakah file konfigurasi ada
if [ ! -f "$CONFIG_FILE" ]; then
    error "File konfigurasi SSH tidak ditemukan di $CONFIG_FILE"
    exit 1
fi

# 3. Membuat backup dengan timestamp
BACKUP_FILE="$CONFIG_FILE.bak.$(date +%Y-%m-%d_%H%M%S)"
info "Membuat backup file konfigurasi ke $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

# 4. Memeriksa dan mengubah 'PermitRootLogin'
if grep -qE "^PermitRootLogin\s+yes" "$CONFIG_FILE"; then
    info "'PermitRootLogin yes' sudah dikonfigurasi."
else
    peringatan "Mengubah 'PermitRootLogin' menjadi 'yes'..."
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$CONFIG_FILE"
    PERUBAHAN_DIBUAT=1
fi

# 5. Memeriksa dan mengubah 'PasswordAuthentication'
if grep -qE "^PasswordAuthentication\s+yes" "$CONFIG_FILE"; then
    info "'PasswordAuthentication yes' sudah dikonfigurasi."
else
    peringatan "Mengubah 'PasswordAuthentication' menjadi 'yes'..."
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$CONFIG_FILE"
    PERUBAHAN_DIBUAT=1
fi

# 6. Me-restart layanan SSH hanya jika ada perubahan
if [ "$PERUBAHAN_DIBUAT" -eq 1 ]; then
    info "Perubahan terdeteksi. Me-restart layanan SSH..."
    if systemctl list-units --type=service | grep -q 'sshd.service'; then
        systemctl restart sshd
        info "Layanan 'sshd' berhasil di-restart."
    elif systemctl list-units --type=service | grep -q 'ssh.service'; then
        systemctl restart ssh
        info "Layanan 'ssh' berhasil di-restart."
    else
        error "Tidak dapat menemukan layanan ssh atau sshd untuk di-restart. Silakan restart manual."
    fi
else
    info "Tidak ada perubahan konfigurasi yang dibuat. Restart tidak diperlukan."
fi

echo ""
info "======================================================"
info "Konfigurasi SSH selesai!"
info "======================================================"

exit 0

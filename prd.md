PRD: Celengan Pintar IoT & Flutter (Firebase Edition)
Dokumen kebutuhan produk ini diperbarui untuk mencerminkan arsitektur Firebase Realtime Database (NoSQL JSON) guna mendukung siklus iterasi cepat (vibe coding).

1. Ringkasan & Tujuan Produk
Celengan pintar berbasis ESP32 yang mendeteksi uang masuk secara otomatis, mencatat transaksi langsung ke JSON tree di Firebase via REST API, dan menyinkronkan saldo ke aplikasi Flutter milik orang tua secara instan (realtime).

Masalah: Orang tua sulit memantau konsistensi dan nominal tabungan anak dari celengan fisik tanpa harus membongkarnya.

Solusi: Celengan IoT yang terhubung ke Firebase Realtime Database sehingga perubahan saldo langsung muncul di layar HP orang tua kurang dari 1 detik.

2. Pengguna Produk
Anak (Primary User - Hardware): Memasukkan koin ke celengan fisik dan mendapat umpan balik langsung (LED/buzzer).

Orang Tua (Primary User - Mobile App): Memantau saldo akumulatif, melihat log setoran terakhir, dan memantau progres target tabungan.

3. Arsitektur & Kebutuhan Fungsional
A. Perangkat Keras (ESP32)
Pendeteksian Koin: Mendeteksi koin (misal Rp500 dan Rp1.000) lewat sensor saklar optik, microswitch, atau multi-coin acceptor.

Pengiriman Data:

Menghubungkan ke Wi-Fi.

Mengirim HTTP PATCH ke endpoint `https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app/celengan_01.json`.

Memanfaatkan payload server-value bawaan Firebase: {"saldo": {".sv": {"increment": nominal}}} untuk mencegah race condition.

Simulasi & Prototyping: Diuji coba terlebih dahulu menggunakan simulator Wokwi sebelum dirakit ke komponen fisik.

B. Backend & Penyimpanan (Firebase Realtime Database)
Penyimpanan Berbasis JSON: Menggunakan struktur node pohon (JSON tree) tanpa skema tabel statis.

Atomic Increment: Penjumlahan saldo diproses di sisi server Firebase, sehingga data saldo tetap akurat meski ada request bertubi-tubi.

Realtime Sync: Perubahan node database langsung dipancarkan melalui koneksi WebSocket bawaan Firebase ke aplikasi Flutter.

C. Aplikasi Mobile (Flutter)
Dashboard Saldo:

Menampilkan total saldo terkini menggunakan widget StreamBuilder / listener onValue.

Animasi pertambahan angka ketika ada koin baru masuk.

Info Transaksi Terakhir:

Menampilkan nominal koin terakhir yang dimasukkan anak dan waktu setoran.

Target Tabungan (Savings Goal):

Bar persentase pencapaian berdasarkan target nominal yang ditentukan orang tua.

4. Struktur Data (Firebase JSON Tree)
JSON
{
  "celengan_01": {
    "info": {
      "nama_anak": "Azka",
      "target_nominal": 100000,
      "target_nama": "Sepeda Baru"
    },
    "saldo": 15000,
    "terakhir_masuk": 1000,
    "riwayat": {
      "-OAxYz123456": {
        "nominal": 1000,
        "timestamp": 1729938000000
      },
      "-OAxYz789012": {
        "nominal": 500,
        "timestamp": 1729938300000
      }
    }
  }
}
Security Rules (Fase Pengembangan)
JSON
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
5. Kebutuhan Non-Fungsional
Latensi Sinkronisasi: Saldo di layar aplikasi Flutter terbarui dalam waktu kurang dari 1 detik setelah koin masuk.

Efisiensi Daya & Jaringan: ESP32 hanya membuka koneksi HTTP singkat (stateless) saat ada koin masuk untuk menghemat daya dan memori.

Skalabilitas Vibe Coding: Kode Flutter dan ESP32 dibuat modular dan mandiri (tanpa dependensi backend kustom/kompleks).

6. Roadmap Implementasi (Vibe Coding Loop)
[ Wokwi ESP32 ] ---> (HTTP PATCH) ---> [ Firebase RTDB ] ---> (Realtime Stream) ---> [ Flutter App ]
Sprint 1 (Cloud & IoT Virtual) - SELESAI:

Inisialisasi Firebase Realtime Database (Test Mode).

Konfigurasi simulasi tombol koin di Wokwi ESP32 dengan HTTP PATCH atomic increment.

Sprint 2 (Frontend Flutter):

Integrasi dependensi firebase_core dan firebase_database.

Implementasi UI dashboard realtime sederhana di main.dart.

Uji coba end-to-end: klik tombol di Wokwi ➔ saldo di Flutter bertambah otomatis.

Sprint 3 (Hardware Nyata):

Flash kode ke ESP32 fisik.

Wiring modul koin/saklar mekanik dan pengujian jaringan Wi-Fi lokal.
# Celenganku App (Flutter + Firebase Realtime Database)

Aplikasi mobile monitoring Celengan Pintar IoT berbasis **Flutter** dan **Firebase Realtime Database**. Aplikasi ini menerima sinyal perubahan saldo secara instan (< 1 detik) saat koin dimasukkan ke celengan fisik/simulasi ESP32.

---

## 🚀 Fitur Utama

1. **Realtime Saldo Sync (SSE / WebSocket):** Total saldo selalu sinkron tanpa perlu me-refresh aplikasi.
2. **Animasi Rolling Saldo:** Angka bertambah halus saat koin baru terdeteksi.
3. **Info Terakhir Masuk:** Menampilkan nominal koin terakhir yang dimasukkan anak dan waktu setoran.
4. **Target Tabungan (Savings Goal):** Progress bar animasi persentase target impian (misal: "Sepeda Baru" Rp 100.000).
5. **Riwayat Koin Masuk:** Catatan transaksi waktu nyata dengan format mata uang Rupiah dan penanggalan ramah anak/orang tua.
6. **Simulasi Sensor Koin:** Tombol simulasi langsung di aplikasi untuk menguji transmisi data koin ke Firebase tanpa harus menyalakan hardware.
7. **Pengaturan Dinamis:** Konfigurasi URL Firebase dan Device ID langsung dari layar Settings.

---

## 🛠️ Cara Menjalankan

### Prasyarat

Pastikan Flutter SDK sudah terpasang di komputer Anda.
Jika belum terpasang di Windows, Anda dapat menginstalnya via terminal:

```powershell
winget install Flutter.Flutter
```

### Langkah Menjalankan

1. Buka folder aplikasi di terminal:

   ```bash
   cd d:\ngodink\celenganku\celenganku_app
   ```

2. Ambil dependensi:

   ```bash
   flutter pub get
   ```

3. Jalankan aplikasi (Chrome Web / Emulator Android / HP Fisik):

   ```bash
   flutter run -d chrome
   # atau untuk Android
   flutter run
   ```

---

## 🔒 Konfigurasi Firebase Realtime Database

- **Database URL**: `https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app`

Pada Firebase Console, aktifkan **Realtime Database** dan atur Security Rules (Fase Pengembangan):

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

Format JSON node yang digunakan:

```json
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
      }
    }
  }
}
```

# Simulasi Celengan Pintar IoT (ESP32 Wokwi)

Panduan menjalankan simulasi perangkat keras celengan IoT menggunakan simulator Wokwi.

---

## 📋 Komponen Simulasi

1. **ESP32 DevKit v4**
2. **Pushbutton 1 (Orange, Pin 18):** Simulasi deteksi Koin Rp 500
3. **Pushbutton 2 (Hijau, Pin 19):** Simulasi deteksi Koin Rp 1.000
4. **Buzzer Piezo (Pin 21):** Umpan balik nada suara saat koin berhasil masuk
5. **LED Indikator (Pin 2):** Lampu kedip konfirmasi transmisi data

---

## ⚡ Cara Menjalankan di Wokwi

1. Buka [Wokwi ESP32 New Project](https://wokwi.com/projects/new/esp32).
2. Salin seluruh isi file [sketch.ino](file:///d:/ngodink/celenganku/wokwi/sketch.ino) ke tab kode `sketch.ino`.
3. Salin isi file [diagram.json](file:///d:/ngodink/celenganku/wokwi/diagram.json) ke tab `diagram.json`.
4. URL Firebase sudah otomatis diarahkan ke database Anda:

   ```cpp
   const String FIREBASE_URL = "https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app/celengan_01.json";
   ```

5. Klik tombol **Play / Start Simulation**.
6. Tekan tombol **Koin 500** atau **Koin 1000** di layar simulasi:
   - ESP32 membunyikan nada buzzer dan menyalakan LED.
   - Mengirim HTTP PATCH atomic increment ke Firebase Realtime Database.
   - Saldo di aplikasi Flutter langsung bertambah dalam waktu < 1 detik.

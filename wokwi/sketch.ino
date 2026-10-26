/*
  Celengan Pintar IoT - ESP32 Firmware (Wokwi & Hardware)
  PRD: Celengan Pintar IoT & Flutter (Firebase Edition)
  
  Cara Kerja:
  1. Terhubung ke Wi-Fi (Wokwi-GUEST untuk simulator Wokwi).
  2. Tombol 1 (GPIO 18) mendeteksi Koin Rp 500.
  3. Tombol 2 (GPIO 19) mendeteksi Koin Rp 1.000.
  4. Mengirim HTTP PATCH ke Firebase Realtime Database dengan server value atomic increment:
     {"saldo": {".sv": {"increment": nominal}}, "terakhir_masuk": nominal}
  5. Menyalakan LED feedback & Buzzer saat koin terdeteksi.
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// Konfigurasi Wi-Fi (Gunakan Wokwi-GUEST untuk simulator Wokwi)
const char* ssid = "Wokwi-GUEST";
const char* password = "";

// Ganti dengan URL Firebase Realtime Database Anda
const String FIREBASE_URL = "https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app/celengan_01.json";

// Definisi Pin
const int PIN_KOIN_500  = 18; // Tombol / Sensor Koin Rp 500
const int PIN_KOIN_1000 = 19; // Tombol / Sensor Koin Rp 1000
const int PIN_LED       = 2;  // LED Indikator Status
const int PIN_BUZZER    = 21; // Buzzer Bunyi Koin

// Debounce & State Tracking
unsigned long lastDebounceTime500 = 0;
unsigned long lastDebounceTime1000 = 0;
const unsigned long DEBOUNCE_DELAY = 300; // ms

void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PIN_KOIN_500, INPUT_PULLUP);
  pinMode(PIN_KOIN_1000, INPUT_PULLUP);
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);

  digitalWrite(PIN_LED, LOW);
  digitalWrite(PIN_BUZZER, LOW);

  Serial.println("\n=================================");
  Serial.println("  CELENGAN PINTAR IoT (ESP32)   ");
  Serial.println("=================================");

  connectWiFi();
}

void loop() {
  // Pastikan Wi-Fi tetap terhubung
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  // Deteksi Koin Rp 500
  if (digitalRead(PIN_KOIN_500) == LOW) {
    if (millis() - lastDebounceTime500 > DEBOUNCE_DELAY) {
      lastDebounceTime500 = millis();
      Serial.println("\n[SENSOR] Koin Rp 500 Terdeteksi!");
      handleCoinInserted(500);
    }
  }

  // Deteksi Koin Rp 1.000
  if (digitalRead(PIN_KOIN_1000) == LOW) {
    if (millis() - lastDebounceTime1000 > DEBOUNCE_DELAY) {
      lastDebounceTime1000 = millis();
      Serial.println("\n[SENSOR] Koin Rp 1.000 Terdeteksi!");
      handleCoinInserted(1000);
    }
  }

  delay(20);
}

void connectWiFi() {
  Serial.print("Menghubungkan ke Wi-Fi: ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    delay(500);
    Serial.print(".");
    digitalWrite(PIN_LED, !digitalRead(PIN_LED));
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(PIN_LED, HIGH);
    Serial.println("\n[Wi-Fi] Terhubung! IP: " + WiFi.localIP().toString());
    feedbackSuccess();
  } else {
    digitalWrite(PIN_LED, LOW);
    Serial.println("\n[Wi-Fi] Gagal terhubung. Akan dicoba kembali di loop.");
  }
}

void handleCoinInserted(int nominal) {
  // 1. Umpan balik fisik lokal untuk anak (LED & Buzzer)
  tone(PIN_BUZZER, 1800, 100);
  digitalWrite(PIN_LED, HIGH);

  // 2. Kirim HTTP PATCH Atomic Increment ke Firebase
  sendFirebasePatch(nominal);

  digitalWrite(PIN_LED, LOW);
}

void sendFirebasePatch(int nominal) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[ERROR] Wi-Fi tidak terhubung, gagal mengirim koin!");
    return;
  }

  WiFiClientSecure client;
  client.setInsecure(); // Mengabaikan verifikasi SSL untuk koneksi ringan ESP32

  HTTPClient http;
  http.begin(client, FIREBASE_URL);
  http.addHeader("Content-Type", "application/json");

  // Payload Atomic Increment bawaan Firebase Server-Value
  // {"saldo": {".sv": {"increment": nominal}}, "terakhir_masuk": nominal}
  String payload = "{\"saldo\":{\".sv\":{\"increment\":" + String(nominal) + "}},\"terakhir_masuk\":" + String(nominal) + "}";

  Serial.println("[HTTP] Mengirim HTTP PATCH ke Firebase...");
  Serial.println("[HTTP] Payload: " + payload);

  unsigned long startMs = millis();
  int httpResponseCode = http.PATCH(payload);
  unsigned long latency = millis() - startMs;

  if (httpResponseCode > 0) {
    Serial.printf("[HTTP] Sukses! Response Code: %d (Latency: %lu ms)\n", httpResponseCode, latency);
    String response = http.getString();
    Serial.println("[HTTP] Response: " + response);
    feedbackSuccess();
  } else {
    Serial.printf("[HTTP] Gagal mengirim PATCH. Error: %s\n", http.errorToString(httpResponseCode).c_str());
  }

  http.end();
}

void feedbackSuccess() {
  tone(PIN_BUZZER, 2400, 80);
  delay(100);
  tone(PIN_BUZZER, 3000, 120);
}

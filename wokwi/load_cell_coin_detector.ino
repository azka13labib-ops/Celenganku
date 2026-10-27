/*
  =============================================================================
  CELENGAN PINTAR IoT - ESP32 FIRMWARE WITH LOAD CELL & FEEDBACK SUBSCRIBER
  =============================================================================
  Hardware:
  - ESP32 NodeMCU
  - Load Cell (500g / 1kg) + HX711 ADC Module (24-bit)
  - Piezo Buzzer (PWM tone) & Status LED
  
  Fitur Utama:
  1. Load Cell Signal Processing: Exponential Moving Average (EMA) & Rolling Filter.
  2. Vibration/Shock Debounce: Menolak spike benturan mekanis dan menunggu kestabilan bobot.
  3. Klasifikasi Koin Rupiah: Pemetaan delta berat (gram) ke pecahan Rp 100, 200, 500, 1000.
  4. Hardware Feedback Subscriber: Men-subscribe node Firebase /feedback untuk mengontrol buzzer & LED.
  =============================================================================
*/

#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include "HX711.h"

// ----------------------------------------------------------------------------
// KONFIGURASI WI-FI & FIREBASE REALTIME DATABASE
// ----------------------------------------------------------------------------
const char* WIFI_SSID     = "Wokwi-GUEST";
const char* WIFI_PASSWORD = "";

const String FIREBASE_HOST = "https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app";
const String DEVICE_ID     = "celengan_01";

// ----------------------------------------------------------------------------
// PIN ASSIGNMENT
// ----------------------------------------------------------------------------
const int PIN_HX711_DOUT   = 16; // Data Load Cell
const int PIN_HX711_SCK    = 4;  // Clock Load Cell
const int PIN_BUZZER       = 21; // PWM Buzzer
const int PIN_LED_STATUS   = 2;  // Indikator LED

// ----------------------------------------------------------------------------
// LOAD CELL & COIN ALGORITHM PARAMETERS
// ----------------------------------------------------------------------------
HX711 scale;

// Faktor kalibrasi (sesuaikan dengan modul fisik: nilai_adc / berat_standar)
const float CALIBRATION_FACTOR = 420.0f;

// Filter EMA (Exponential Moving Average)
const float EMA_ALPHA = 0.25f;
float filteredWeight = 0.0f;
float baselineWeight = 0.0f;

// Parameter Deteksi Kestabilan & Anti-Guncangan (Debounce)
const float MIN_COIN_DELTA_THRESHOLD   = 1.2f;  // Gram minimum untuk mendeteksi koin masuk
const float STABILITY_TOLERANCE_GRAMS  = 0.18f; // Variasi maksimum antar pembacaan stabil
const int   REQUIRED_STABLE_SAMPLES    = 4;     // Jumlah pembacaan stabil berturut-turut
const unsigned long SETTLING_DELAY_MS  = 200;   // Jeda peredaman getaran mekanis saat koin jatuh

// Timer Polling Firebase Feedback
unsigned long lastFeedbackCheck = 0;
const unsigned long FEEDBACK_POLL_INTERVAL_MS = 2500;
long lastRewardTriggerId = 0;

// ----------------------------------------------------------------------------
// SPESIFIKASI BERAT KOIN BANK INDONESIA (GRAM)
// ----------------------------------------------------------------------------
// Rp 100  (Aluminium)               : ~1.79g  (Rentang: 1.65g - 1.95g)
// Rp 200  (Aluminium)               : ~2.38g  (Rentang: 2.20g - 2.58g)
// Rp 500  (Aluminium)               : ~3.10g  (Rentang: 2.85g - 3.40g)
// Rp 1000 (Nickel-Plated Steel)     : ~4.50g  (Rentang: 4.25g - 4.85g)
// Rp 500  (Kuningan Lama / Kuning)  : ~5.34g  (Rentang: 5.10g - 5.60g)
int classifyCoinNominal(float deltaGram) {
  if (deltaGram >= 1.65f && deltaGram <= 1.95f) {
    return 100;
  } else if (deltaGram >= 2.20f && deltaGram <= 2.58f) {
    return 200;
  } else if (deltaGram >= 2.85f && deltaGram <= 3.40f) {
    return 500;
  } else if (deltaGram >= 4.25f && deltaGram <= 4.85f) {
    return 1000;
  } else if (deltaGram >= 5.10f && deltaGram <= 5.60f) {
    return 500; // Pecahan Rp 500 kuningan model lama
  }
  return 0; // Tidak terdefinisi / noise guncangan
}

// ----------------------------------------------------------------------------
// SETUP HARDWARE
// ----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PIN_LED_STATUS, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_LED_STATUS, LOW);
  digitalWrite(PIN_BUZZER, LOW);

  Serial.println("\n==============================================");
  Serial.println("  CELENGAN PINTAR IoT - LOAD CELL ENGINE      ");
  Serial.println("==============================================");

  // Inisialisasi Load Cell HX711
  scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);
  scale.set_scale(CALIBRATION_FACTOR);
  
  Serial.println("[LOAD CELL] Mengkalibrasi titik nol (Tare)...");
  scale.tare(15);
  baselineWeight = scale.get_units(10);
  filteredWeight = baselineWeight;
  Serial.printf("[LOAD CELL] Titik nol awal: %.2f gram\n", baselineWeight);

  connectWiFi();
  playSuccessChime();
}

// ----------------------------------------------------------------------------
// MAIN LOOP
// ----------------------------------------------------------------------------
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  // 1. Baca dan Filter Sinyal Load Cell
  processLoadCellReading();

  // 2. Cek Subscriber Kontrol Feedback dari Firebase
  if (millis() - lastFeedbackCheck > FEEDBACK_POLL_INTERVAL_MS) {
    lastFeedbackCheck = millis();
    checkHardwareFeedbackFromFirebase();
  }

  delay(30);
}

// ----------------------------------------------------------------------------
// ALGORITMA DETEKSI KOIN & ANTI-GUNCANGAN
// ----------------------------------------------------------------------------
void processLoadCellReading() {
  if (!scale.is_ready()) return;

  float rawWeight = scale.get_units(1);
  
  // Exponential Moving Average filter untuk meredam derau frekuensi tinggi ADC
  filteredWeight = (EMA_ALPHA * rawWeight) + ((1.0f - EMA_ALPHA) * filteredWeight);
  float currentDelta = filteredWeight - baselineWeight;

  // Deteksi anomali kenaikan bobot di atas batas noise
  if (currentDelta >= MIN_COIN_DELTA_THRESHOLD) {
    Serial.printf("[SENSOR] Terdeteksi kenaikan bobot awal: +%.2f gram. Menunggu redaman guncangan...\n", currentDelta);
    
    // Beri jeda peredaman osilasi mekanis wadah celengan
    delay(SETTLING_DELAY_MS);

    // Kumpulkan N pembacaan stabil berturut-turut
    float sampleBuffer[REQUIRED_STABLE_SAMPLES];
    bool isStable = true;

    for (int i = 0; i < REQUIRED_STABLE_SAMPLES; i++) {
      sampleBuffer[i] = scale.get_units(2);
      delay(50);
    }

    // Hitung rata-rata dan verifikasi deviasi kestabilan
    float sum = 0;
    for (int i = 0; i < REQUIRED_STABLE_SAMPLES; i++) sum += sampleBuffer[i];
    float stableAverage = sum / REQUIRED_STABLE_SAMPLES;

    for (int i = 0; i < REQUIRED_STABLE_SAMPLES; i++) {
      if (abs(sampleBuffer[i] - stableAverage) > STABILITY_TOLERANCE_GRAMS) {
        isStable = false;
        break;
      }
    }

    if (isStable) {
      float finalDelta = stableAverage - baselineWeight;
      int recognizedNominal = classifyCoinNominal(finalDelta);

      if (recognizedNominal > 0) {
        Serial.println("\n-------------------------------------------");
        Serial.printf(">>> VALIDASI KOIN SUKSES!\n");
        Serial.printf("    Delta Bobot Terukur: %.2f gram\n", finalDelta);
        Serial.printf("    Nominal Terklasifikasi: Rp %d\n", recognizedNominal);
        Serial.println("-------------------------------------------");

        // Perbarui baseline bobot ke bobot baru
        baselineWeight = stableAverage;

        // Umpan balik lokal cepat
        playCoinAcceptedTone();

        // Kirim transaksi ke cloud Firebase
        syncCoinDepositToFirebase(recognizedNominal, finalDelta, stableAverage);
      } else {
        Serial.printf("[REJECT] Objek/guncangan tidak cocok pecahan koin (Delta: %.2f gram)\n", finalDelta);
      }
    } else {
      Serial.println("[REJECT] Pembacaan tidak stabil (kemungkinan guncangan luar wadah).");
    }
  } else if (currentDelta < -2.0f) {
    // Penanganan jika uang diambil dari wadah (berat berkurang drastis)
    Serial.printf("[TARE UPDATE] Wadah berkurang bobot. Memperbarui baseline ke %.2f gram\n", filteredWeight);
    baselineWeight = filteredWeight;
  }
}

// ----------------------------------------------------------------------------
// SINKRONISASI KE FIREBASE REALTIME DATABASE (ATOMIC INCREMENT & LOG)
// ----------------------------------------------------------------------------
void syncCoinDepositToFirebase(int nominal, float coinWeight, float totalWeight) {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure(); // Menggunakan SSL tanpa validasi sertifikat manual pada ESP32
  HTTPClient https;

  String endpoint = FIREBASE_HOST + "/celengan/" + DEVICE_ID + ".json";

  if (https.begin(client, endpoint)) {
    https.addHeader("Content-Type", "application/json");

    // Membuat JSON Payload untuk memperbarui data saldo dan log transaksi baru
    DynamicJsonDocument doc(512);
    doc["data"]["saldo"][".sv"]["increment"] = nominal;
    doc["data"]["terakhir_masuk"] = nominal;
    doc["data"]["berat_total_gram"] = totalWeight;

    // Log Transaksi append
    String txKey = "tx_" + String(millis());
    JsonObject tx = doc["transaksi"][txKey].to<JsonObject>();
    tx["nominal"] = nominal;
    tx["uid"] = "esp32_" + DEVICE_ID;
    tx["tipe"] = "koin_otomatis";
    tx["berat_gram"] = coinWeight;
    tx["timestamp"][".sv"] = "timestamp";

    String jsonPayload;
    serializeJson(doc, jsonPayload);

    int httpCode = https.PATCH(jsonPayload);
    if (httpCode == HTTP_CODE_OK) {
      Serial.printf("[FIREBASE] Setoran Rp %d berhasil dicatat ke cloud!\n", nominal);
    } else {
      Serial.printf("[FIREBASE] Gagal sinkronisasi. Kode HTTP: %d\n", httpCode);
    }
    https.end();
  }
}

// ----------------------------------------------------------------------------
// SUBSCRIBER KONTROL HARDWARE (FIREBASE -> ESP32)
// ----------------------------------------------------------------------------
void checkHardwareFeedbackFromFirebase() {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient https;

  String endpoint = FIREBASE_HOST + "/celengan/" + DEVICE_ID + "/feedback.json";

  if (https.begin(client, endpoint)) {
    int httpCode = https.GET();
    if (httpCode == HTTP_CODE_OK) {
      String payload = https.getString();
      DynamicJsonDocument doc(256);
      deserializeJson(doc, payload);

      bool buzzerActive = doc["buzzer_active"] | false;
      bool ledStatus    = doc["led_status"] | false;
      long rewardTrigger= doc["reward_tone_trigger"] | 0;

      // 1. Eksekusi Status LED
      digitalWrite(PIN_LED_STATUS, ledStatus ? HIGH : LOW);

      // 2. Eksekusi Bunyi Buzzer Langsung
      if (buzzerActive) {
        Serial.println("[FEEDBACK] Perintah Buzzer Aktif diterima dari aplikasi!");
        tone(PIN_BUZZER, 2400, 300);
        
        // Reset state buzzer_active kembali ke false di Firebase (Handshake clear)
        resetBuzzerStateOnFirebase();
      }

      // 3. Eksekusi Nada Kemenangan / Reward
      if (rewardTrigger > lastRewardTriggerId && rewardTrigger != 0) {
        lastRewardTriggerId = rewardTrigger;
        Serial.println("[FEEDBACK] Target Tercapai! Memainkan nada reward...");
        playCelebrationFanfare();
      }
    }
    https.end();
  }
}

void resetBuzzerStateOnFirebase() {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient https;
  String endpoint = FIREBASE_HOST + "/celengan/" + DEVICE_ID + "/feedback.json";

  if (https.begin(client, endpoint)) {
    https.addHeader("Content-Type", "application/json");
    https.PATCH("{\"buzzer_active\":false}");
    https.end();
  }
}

// ----------------------------------------------------------------------------
// NADA & INDIKATOR FEEDBACK
// ----------------------------------------------------------------------------
void playCoinAcceptedTone() {
  tone(PIN_BUZZER, 1975, 80); // B6
  delay(90);
  tone(PIN_BUZZER, 2637, 120); // E7
}

void playSuccessChime() {
  tone(PIN_BUZZER, 1318, 100); // E6
  delay(110);
  tone(PIN_BUZZER, 1567, 100); // G6
  delay(110);
  tone(PIN_BUZZER, 2093, 200); // C7
}

void playCelebrationFanfare() {
  int melody[] = { 1318, 1318, 1318, 1046, 1318, 1567, 784 };
  int durations[] = { 120, 120, 120, 100, 120, 250, 250 };
  for (int i = 0; i < 7; i++) {
    tone(PIN_BUZZER, melody[i], durations[i]);
    delay(durations[i] * 1.3);
  }
}

void connectWiFi() {
  Serial.printf("[Wi-Fi] Menghubungkan ke %s...\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    delay(400);
    digitalWrite(PIN_LED_STATUS, !digitalRead(PIN_LED_STATUS));
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(PIN_LED_STATUS, HIGH);
    Serial.printf("[Wi-Fi] Sukses! IP: %s\n", WiFi.localIP().toString().c_str());
  }
}

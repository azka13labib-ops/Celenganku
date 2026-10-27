/*
  =============================================================================
  CELENGAN PINTAR IoT - DUAL SENSOR ENGINE (KOIN & UANG KERTAS RUPIAH)
  =============================================================================
  Hardware:
  - ESP32 NodeMCU
  - Load Cell (1kg) + HX711 ADC 24-bit (Deteksi Koin Fisik Rupiah)
  - Sensor Optik RGB TCS34725 / TCS3200 + Sensor Celah IR TCRT5000 (Deteksi Uang Kertas)
  - Feeder Motor Driver (GPIO 27) untuk menarik uang kertas masuk ke brankas
  - Piezo Buzzer (PWM tone) & Status LED
  
  Metode Deteksi Uang Kertas:
  Catatan: Bobot selembar uang kertas Rupiah sangat ringan (~0.8 s.d. 1.0 gram)
  dan identik untuk semua pecahan, sehingga load cell TIDAK DAPAT membedakan pecahan.
  Sistem ini menggunakan Sensor Warna Spektral (TCS34725) + Sensor Panjang Optik
  untuk membedakan spektrum warna dominan emisi Bank Indonesia (TE 2016 & TE 2022).
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
// Sensor Koin (Load Cell HX711)
const int PIN_HX711_DOUT    = 16;
const int PIN_HX711_SCK     = 4;

// Sensor Uang Kertas (Celah Slot IR & Motor Feeder)
const int PIN_SLOT_IR       = 14; // Sensor IR deteksi kertas diselipkan (Active LOW)
const int PIN_MOTOR_FEEDER  = 27; // Penggerak rol penarik uang (Relay / Transistor)

// Indikator Umpan Balik Hardware
const int PIN_BUZZER        = 21; // PWM Buzzer
const int PIN_LED_STATUS    = 2;  // Indikator LED

// ----------------------------------------------------------------------------
// LOAD CELL & COIN PARAMETERS
// ----------------------------------------------------------------------------
HX711 scale;
const float CALIBRATION_FACTOR = 420.0f;
const float EMA_ALPHA = 0.25f;
float filteredWeight = 0.0f;
float baselineWeight = 0.0f;

const float MIN_COIN_DELTA_THRESHOLD   = 1.2f;
const float STABILITY_TOLERANCE_GRAMS  = 0.18f;
const int   REQUIRED_STABLE_SAMPLES    = 4;
const unsigned long SETTLING_DELAY_MS  = 200;

// Timer Polling Firebase Feedback
unsigned long lastFeedbackCheck = 0;
const unsigned long FEEDBACK_POLL_INTERVAL_MS = 2500;
long lastRewardTriggerId = 0;

// ----------------------------------------------------------------------------
// TABEL SPESIFIKASI BERAT KOIN BANK INDONESIA (GRAM)
// ----------------------------------------------------------------------------
int classifyCoinNominal(float deltaGram) {
  if (deltaGram >= 1.65f && deltaGram <= 1.95f) return 100;
  if (deltaGram >= 2.20f && deltaGram <= 2.58f) return 200;
  if (deltaGram >= 2.85f && deltaGram <= 3.40f) return 500;
  if (deltaGram >= 4.25f && deltaGram <= 4.85f) return 1000;
  if (deltaGram >= 5.10f && deltaGram <= 5.60f) return 500; // Kuningan lama
  return 0;
}

// ----------------------------------------------------------------------------
// TABEL SPEKTRUM WARNA UANG KERTAS RUPIAH (TE 2016 / TE 2022)
// ----------------------------------------------------------------------------
// Rp 100.000: Merah Dominan   (R tinggi, G rendah, B rendah)
// Rp 50.000 : Biru Dominan    (B tinggi, R rendah)
// Rp 20.000 : Hijau Dominan   (G tinggi, R rendah, B sedang)
// Rp 10.000 : Ungu Dominan    (R & B tinggi, G rendah)
// Rp 5.000  : Cokelat Dominan (R & G sedang, B rendah)
// Rp 2.000  : Abu-abu Netral  (R, G, B seimbang)
// Rp 1.000  : Kuning Zaitun   (R & G tinggi, B rendah)
struct BanknoteClassification {
  int nominal;
  const char* warna;
};

BanknoteClassification classifyBanknoteByColor(int red, int green, int blue) {
  // Hitung total intensitas dan rasio
  int maxVal = max(red, max(green, blue));
  int minVal = min(red, min(green, blue));
  int delta = maxVal - minVal;

  // 1. Rp 100.000 (Merah)
  if (red > 170 && green < 100 && blue < 100) {
    return {100000, "Merah (Rp 100.000)"};
  }

  // 2. Rp 50.000 (Biru)
  if (blue > 160 && red < 90 && green < 140) {
    return {50000, "Biru (Rp 50.000)"};
  }

  // 3. Rp 20.000 (Hijau)
  if (green > 150 && red < 100 && blue < 120) {
    return {20000, "Hijau (Rp 20.000)"};
  }

  // 4. Rp 10.000 (Ungu)
  if (blue > 130 && red > 120 && green < 90) {
    return {10000, "Ungu (Rp 10.000)"};
  }

  // 5. Rp 5.000 (Cokelat)
  if (red > 140 && green > 90 && green < 140 && blue < 80) {
    return {5000, "Cokelat (Rp 5.000)"};
  }

  // 6. Rp 2.000 (Abu-abu Netral)
  if (delta < 25 && red > 90 && red < 160) {
    return {2000, "Abu-abu (Rp 2.000)"};
  }

  // 7. Rp 1.000 (Kuning Kehijauan)
  if (red > 130 && green > 130 && blue < 85) {
    return {1000, "Kuning Zaitun (Rp 1.000)"};
  }

  return {0, "Tidak Dikenal"};
}

// ----------------------------------------------------------------------------
// SETUP HARDWARE
// ----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PIN_SLOT_IR, INPUT_PULLUP);
  pinMode(PIN_MOTOR_FEEDER, OUTPUT);
  pinMode(PIN_LED_STATUS, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);

  digitalWrite(PIN_MOTOR_FEEDER, LOW);
  digitalWrite(PIN_LED_STATUS, LOW);
  digitalWrite(PIN_BUZZER, LOW);

  Serial.println("\n==============================================");
  Serial.println("  CELENGAN PINTAR IoT - DUAL SENSOR ONLINE    ");
  Serial.println("  [Koin: Load Cell]  |  [Kertas: Sensor Optik]");
  Serial.println("==============================================");

  // Inisialisasi Load Cell HX711
  scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);
  scale.set_scale(CALIBRATION_FACTOR);
  
  Serial.println("[LOAD CELL] Kalibrasi titik nol tare koin...");
  scale.tare(10);
  baselineWeight = scale.get_units(5);
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

  // 1. Cek Deteksi Uang Kertas pada Celah Slot
  processBanknoteSlot();

  // 2. Cek Deteksi Koin pada Wadah Load Cell
  processLoadCellReading();

  // 3. Cek Subscriber Kontrol Feedback dari Firebase
  if (millis() - lastFeedbackCheck > FEEDBACK_POLL_INTERVAL_MS) {
    lastFeedbackCheck = millis();
    checkHardwareFeedbackFromFirebase();
  }

  delay(25);
}

// ----------------------------------------------------------------------------
// ALGORITMA DETEKSI UANG KERTAS (SLOT SENSOR + FEEDER + OPTIK)
// ----------------------------------------------------------------------------
void processBanknoteSlot() {
  // Ketika ujung uang kertas diselipkan ke dalam slot celengan
  if (digitalRead(PIN_SLOT_IR) == LOW) {
    Serial.println("\n[UANG KERTAS] Ujung uang kertas terdeteksi di slot!");
    Serial.println("[FEEDER] Mengaktifkan motor rol penarik...");
    
    // Nyalakan motor penarik uang kertas
    digitalWrite(PIN_MOTOR_FEEDER, HIGH);
    tone(PIN_BUZZER, 1200, 60);

    // Ambil sampel pembacaan optik saat lembaran uang ditarik melewati sensor
    // (Dalam hardware nyata: baca register sensor I2C TCS34725 / TCS3200)
    int rSample = 0, gSample = 0, bSample = 0;
    unsigned long startTime = millis();
    int samples = 0;

    while (millis() - startTime < 1200) { // Waktu rol menarik uang
      // Simulasi sampel optik membaca lembaran uang
      // Ganti dengan: tcs.getRawData(&r, &g, &b, &c);
      rSample += random(160, 230);
      gSample += random(30, 80);
      bSample += random(40, 90);
      samples++;
      delay(80);
    }

    // Matikan motor rol penarik
    digitalWrite(PIN_MOTOR_FEEDER, LOW);
    Serial.println("[FEEDER] Motor rol dimatikan. Lembaran uang telah masuk.");

    int avgR = rSample / samples;
    int avgG = gSample / samples;
    int avgB = bSample / samples;

    BanknoteClassification result = classifyBanknoteByColor(avgR, avgG, avgB);

    if (result.nominal > 0) {
      Serial.println("===========================================");
      Serial.printf(">>> VALIDASI UANG KERTAS SUKSES!\n");
      Serial.printf("    Warna Spektral: %s\n", result.warna);
      Serial.printf("    Nominal Terklasifikasi: Rp %d\n", result.nominal);
      Serial.println("===========================================");

      playBanknoteAcceptedTone();
      syncBanknoteDepositToFirebase(result.nominal, result.warna);
    } else {
      Serial.println("[REJECT] Warna uang kertas tidak dapat diverifikasi.");
    }

    delay(800); // Jeda anti-retrigger ganda
  }
}

// ----------------------------------------------------------------------------
// ALGORITMA DETEKSI KOIN (LOAD CELL HX711)
// ----------------------------------------------------------------------------
void processLoadCellReading() {
  if (!scale.is_ready()) return;

  float rawWeight = scale.get_units(1);
  filteredWeight = (EMA_ALPHA * rawWeight) + ((1.0f - EMA_ALPHA) * filteredWeight);
  float currentDelta = filteredWeight - baselineWeight;

  if (currentDelta >= MIN_COIN_DELTA_THRESHOLD) {
    delay(SETTLING_DELAY_MS);

    float sampleBuffer[REQUIRED_STABLE_SAMPLES];
    bool isStable = true;

    for (int i = 0; i < REQUIRED_STABLE_SAMPLES; i++) {
      sampleBuffer[i] = scale.get_units(2);
      delay(40);
    }

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
        Serial.printf("[KOIN] Terdeteksi Koin Rp %d (Delta: %.2f g)\n", recognizedNominal, finalDelta);
        baselineWeight = stableAverage;
        playCoinAcceptedTone();
        syncCoinDepositToFirebase(recognizedNominal, finalDelta, stableAverage);
      }
    }
  }
}

// ----------------------------------------------------------------------------
// SINKRONISASI KE FIREBASE REALTIME DATABASE
// ----------------------------------------------------------------------------
void syncBanknoteDepositToFirebase(int nominal, const char* warna) {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient https;

  String endpoint = FIREBASE_HOST + "/celengan/" + DEVICE_ID + ".json";

  if (https.begin(client, endpoint)) {
    https.addHeader("Content-Type", "application/json");

    DynamicJsonDocument doc(512);
    doc["data"]["saldo"][".sv"]["increment"] = nominal;
    doc["data"]["terakhir_masuk"] = nominal;

    String txKey = "tx_note_" + String(millis());
    JsonObject tx = doc["transaksi"][txKey].to<JsonObject>();
    tx["nominal"] = nominal;
    tx["uid"] = "esp32_slot_feeder";
    tx["tipe"] = "kertas_otomatis";
    tx["warna_deteksi"] = warna;
    tx["timestamp"][".sv"] = "timestamp";

    String jsonPayload;
    serializeJson(doc, jsonPayload);

    int httpCode = https.PATCH(jsonPayload);
    if (httpCode == HTTP_CODE_OK) {
      Serial.printf("[FIREBASE] Uang Kertas Rp %d tercatat di cloud!\n", nominal);
    }
    https.end();
  }
}

void syncCoinDepositToFirebase(int nominal, float coinWeight, float totalWeight) {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient https;

  String endpoint = FIREBASE_HOST + "/celengan/" + DEVICE_ID + ".json";

  if (https.begin(client, endpoint)) {
    https.addHeader("Content-Type", "application/json");

    DynamicJsonDocument doc(512);
    doc["data"]["saldo"][".sv"]["increment"] = nominal;
    doc["data"]["terakhir_masuk"] = nominal;
    doc["data"]["berat_total_gram"] = totalWeight;

    String txKey = "tx_coin_" + String(millis());
    JsonObject tx = doc["transaksi"][txKey].to<JsonObject>();
    tx["nominal"] = nominal;
    tx["uid"] = "esp32_loadcell";
    tx["tipe"] = "koin_otomatis";
    tx["berat_gram"] = coinWeight;
    tx["timestamp"][".sv"] = "timestamp";

    String jsonPayload;
    serializeJson(doc, jsonPayload);

    https.PATCH(jsonPayload);
    https.end();
  }
}

// ----------------------------------------------------------------------------
// SUBSCRIBER KONTROL HARDWARE DARI FIREBASE
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
      DynamicJsonDocument doc(256);
      deserializeJson(doc, https.getString());

      bool buzzerActive  = doc["buzzer_active"] | false;
      bool ledStatus     = doc["led_status"] | false;
      long rewardTrigger = doc["reward_tone_trigger"] | 0;

      digitalWrite(PIN_LED_STATUS, ledStatus ? HIGH : LOW);

      if (buzzerActive) {
        tone(PIN_BUZZER, 2400, 300);
        resetBuzzerStateOnFirebase();
      }

      if (rewardTrigger > lastRewardTriggerId && rewardTrigger != 0) {
        lastRewardTriggerId = rewardTrigger;
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
// NADA FEEDBACK AUDITORY
// ----------------------------------------------------------------------------
void playCoinAcceptedTone() {
  tone(PIN_BUZZER, 1975, 80);
  delay(90);
  tone(PIN_BUZZER, 2637, 120);
}

void playBanknoteAcceptedTone() {
  tone(PIN_BUZZER, 1046, 70); // C6
  delay(80);
  tone(PIN_BUZZER, 1318, 70); // E6
  delay(80);
  tone(PIN_BUZZER, 1567, 70); // G6
  delay(80);
  tone(PIN_BUZZER, 2093, 140); // C7
}

void playSuccessChime() {
  tone(PIN_BUZZER, 1318, 100);
  delay(110);
  tone(PIN_BUZZER, 1567, 100);
  delay(110);
  tone(PIN_BUZZER, 2093, 200);
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
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    delay(400);
    digitalWrite(PIN_LED_STATUS, !digitalRead(PIN_LED_STATUS));
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(PIN_LED_STATUS, HIGH);
  }
}

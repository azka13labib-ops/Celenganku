import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Konfigurasi Global & Inisialisasi Offline Persistence Firebase Realtime Database
class FirebaseConfig {
  static const String projectId = 'celenganku-456f9';
  static const String databaseUrl =
      'https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String defaultCelenganId = 'celengan_01';

  /// Mengaktifkan Offline Data Caching & Persistence pada Firebase Realtime Database
  static Future<void> initializeOfflinePersistence() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyDummyKeyForRealtimeDatabasePublicAccess456f9',
            appId: '1:543210987654:android:celenganku456f9',
            messagingSenderId: '543210987654',
            projectId: projectId,
            databaseURL: databaseUrl,
          ),
        );
      }

      // Aktifkan Offline Persistence (Khusus platform Mobile / Desktop yang didukung)
      if (!kIsWeb) {
        final rtdb = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: databaseUrl,
        );

        // 1. Aktifkan disk persistence agar data tidak hilang saat app dimatikan tanpa internet
        rtdb.setPersistenceEnabled(true);

        // 2. Alokasikan cache hingga 50 MB untuk menampung riwayat transaksi lokal
        rtdb.setPersistenceCacheSizeBytes(50 * 1024 * 1024);

        if (kDebugMode) {
          print('[FirebaseConfig] Offline Data Persistence aktif (50 MB cache).');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseConfig] Catatan Inisialisasi: $e');
      }
    }
  }

  /// Menandai node celengan agar selalu tersinkronisasi otomatis di latar belakang
  static Future<void> enableKeepSynced(String celenganId) async {
    if (kIsWeb) return;
    try {
      final rtdb = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseUrl,
      );
      final ref = rtdb.ref('celengan/$celenganId');
      await ref.keepSynced(true);
    } catch (e) {
      if (kDebugMode) print('[FirebaseConfig] Gagal mengaktifkan keepSynced: $e');
    }
  }
}

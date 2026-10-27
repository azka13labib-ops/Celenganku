import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../../core/config/firebase_config.dart';

class HardwareFeedbackState {
  final bool buzzerActive;
  final bool ledStatus;
  final int rewardToneTrigger;

  const HardwareFeedbackState({
    this.buzzerActive = false,
    this.ledStatus = false,
    this.rewardToneTrigger = 0,
  });

  factory HardwareFeedbackState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const HardwareFeedbackState();
    return HardwareFeedbackState(
      buzzerActive: map['buzzer_active'] == true,
      ledStatus: map['led_status'] == true,
      rewardToneTrigger: (map['reward_tone_trigger'] is int)
          ? map['reward_tone_trigger']
          : 0,
    );
  }
}

/// Repository untuk mengontrol perangkat keras ESP32 melalui node /feedback
class HardwareFeedbackRepository {
  final String celenganId;
  HardwareFeedbackRepository({this.celenganId = FirebaseConfig.defaultCelenganId});

  /// Mengaktifkan atau mematikan Buzzer pada ESP32
  Future<void> setBuzzerActive(bool active) async {
    await _updateFeedbackNode({'buzzer_active': active});
  }

  /// Mengubah status LED pada ESP32
  Future<void> setLedStatus(bool active) async {
    await _updateFeedbackNode({'led_status': active});
  }

  /// Memutar nada kemenangan / fanfare perayaan di buzzer fisik saat target tercapai
  Future<void> triggerRewardMelody() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _updateFeedbackNode({'reward_tone_trigger': timestamp});
  }

  /// Mengambil aliran realtime feedback state
  Stream<HardwareFeedbackState> streamFeedbackState() {
    try {
      if (Firebase.apps.isNotEmpty) {
        final rtdb = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: FirebaseConfig.databaseUrl,
        );
        return rtdb
            .ref('celengan/$celenganId/feedback')
            .onValue
            .map((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            return HardwareFeedbackState.fromMap(data);
          }
          return const HardwareFeedbackState();
        });
      }
    } catch (e) {
      if (kDebugMode) print('Feedback native stream dialihkan ke fallback: $e');
    }

    return _fallbackHttpStream();
  }

  Stream<HardwareFeedbackState> _fallbackHttpStream() async* {
    final endpoint = Uri.parse(
        '${FirebaseConfig.databaseUrl}/celengan/$celenganId/feedback.json');
    try {
      final res = await http.get(endpoint).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body != 'null') {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          yield HardwareFeedbackState.fromMap(decoded);
        }
      }
    } catch (_) {
      yield const HardwareFeedbackState();
    }
  }

  Future<void> _updateFeedbackNode(Map<String, dynamic> patchData) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final rtdb = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: FirebaseConfig.databaseUrl,
        );
        await rtdb.ref('celengan/$celenganId/feedback').update(patchData);
        return;
      }
    } catch (_) {}

    // Fallback via HTTP REST
    final endpoint = Uri.parse(
        '${FirebaseConfig.databaseUrl}/celengan/$celenganId/feedback.json');
    await http.patch(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(patchData),
    );
  }
}

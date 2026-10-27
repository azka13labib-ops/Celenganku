import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/hardware_feedback_repository.dart';

const Color kHeritageForest = Color(0xFF064E3B);
const Color kSageTeal = Color(0xFF0D9488);
const Color kCoinBrass = Color(0xFFD97706);
const Color kDeepSlate = Color(0xFF0F172A);

class HardwareControlSheet extends StatefulWidget {
  final HardwareFeedbackRepository repository;

  const HardwareControlSheet({
    super.key,
    required this.repository,
  });

  @override
  State<HardwareControlSheet> createState() => _HardwareControlSheetState();
}

class _HardwareControlSheetState extends State<HardwareControlSheet> {
  bool _isBuzzerBusy = false;
  bool _isMelodyBusy = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: StreamBuilder<HardwareFeedbackState>(
        stream: widget.repository.streamFeedbackState(),
        builder: (context, snapshot) {
          final state = snapshot.data ?? const HardwareFeedbackState();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.tune_rounded, color: kHeritageForest, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Kontrol Perangkat Keras ESP32',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDeepSlate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Uji komunikasi dua arah antara aplikasi Flutter dan modul fisik celengan:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 20),

              // 1. Kontrol Buzzer (Beep Test)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: kCoinBrass, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tes Bunyi Buzzer',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kDeepSlate),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kirim sinyal beep frekuensi 2.4kHz ke ESP32',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kHeritageForest,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isBuzzerBusy
                            ? null
                            : () async {
                                setState(() => _isBuzzerBusy = true);
                                HapticFeedback.mediumImpact();
                                await widget.repository.setBuzzerActive(true);
                                await Future.delayed(const Duration(milliseconds: 700));
                                if (mounted) setState(() => _isBuzzerBusy = false);
                              },
                        child: _isBuzzerBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Bunyikan'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Kontrol LED Fisik (Toggle Status)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: state.ledStatus ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb_rounded,
                        color: state.ledStatus ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lampu Indikator LED',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kDeepSlate),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.ledStatus ? 'Status fisik: MENYALA' : 'Status fisik: MATI',
                            style: TextStyle(
                              fontSize: 12,
                              color: state.ledStatus ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: state.ledStatus,
                      activeColor: kHeritageForest,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        widget.repository.setLedStatus(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Putar Fanfare / Nada Kemenangan
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kHeritageForest, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isMelodyBusy
                      ? null
                      : () async {
                          setState(() => _isMelodyBusy = true);
                          HapticFeedback.heavyImpact();
                          await widget.repository.triggerRewardMelody();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sinyal Fanfare Kemenangan dikirim ke ESP32!'),
                                backgroundColor: kHeritageForest,
                              ),
                            );
                          }
                          await Future.delayed(const Duration(seconds: 1));
                          if (mounted) setState(() => _isMelodyBusy = false);
                        },
                  icon: const Icon(Icons.celebration_rounded, color: kHeritageForest),
                  label: const Text(
                    'Putar Melodi Reward di ESP32',
                    style: TextStyle(fontWeight: FontWeight.bold, color: kHeritageForest),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

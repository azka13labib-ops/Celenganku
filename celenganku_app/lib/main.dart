import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'core/config/firebase_config.dart';
import 'presentation/analytics/analytics_screen.dart';
import 'presentation/hardware_control/hardware_control_sheet.dart';
import 'data/repositories/hardware_feedback_repository.dart';

// ============================================================================
// KONFIGURASI FIREBASE REALTIME DATABASE (ASIA-SOUTHEAST1)
// ============================================================================
const String kFirebaseProjectId = FirebaseConfig.projectId;
const String kFirebaseDatabaseUrl = FirebaseConfig.databaseUrl;
const String kNodePath = FirebaseConfig.defaultCelenganId;

// Palet Warna Anti AI Slop (Strict 3 Core + 1 Deliberate Accent)
// R-31: Heritage Forest dipilih untuk melambangkan kestabilan dan tabungan riil.
const Color kHeritageForest = Color(0xFF064E3B); // Primary Deep Emerald
const Color kSageTeal = Color(0xFF0D9488);       // Secondary Interactive Teal
const Color kWarmPaper = Color(0xFFF8FAFC);      // Slate 50 Warm Canvas
const Color kCoinBrass = Color(0xFFD97706);      // Deliberate Amber Accent
const Color kDeepSlate = Color(0xFF0F172A);      // Slate 900 Text

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.initializeOfflinePersistence();
  runApp(const CelenganApp());
}


// ============================================================================
// ROOT APPLICATION WIDGET
// ============================================================================
class CelenganApp extends StatelessWidget {
  const CelenganApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celengan Pintar IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kWarmPaper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kHeritageForest,
          primary: kHeritageForest,
          secondary: kSageTeal,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kWarmPaper,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const DashboardCelenganScreen(),
    );
  }
}

// ============================================================================
// MODEL DATA CELENGAN & NOTIFIKASI
// ============================================================================
class CelenganSnapshot {
  final int saldo;
  final int terakhirMasuk;
  final String namaAnak;
  final String targetNama;
  final int targetNominal;
  final bool isConnected;

  const CelenganSnapshot({
    required this.saldo,
    required this.terakhirMasuk,
    required this.namaAnak,
    required this.targetNama,
    required this.targetNominal,
    this.isConnected = true,
  });

  factory CelenganSnapshot.fromMap(Map<dynamic, dynamic>? map, {bool connected = true}) {
    if (map == null) {
      return CelenganSnapshot(
        saldo: 0,
        terakhirMasuk: 0,
        namaAnak: 'Azka',
        targetNama: 'Sepeda Baru',
        targetNominal: 100000,
        isConnected: connected,
      );
    }

    final info = map['info'] as Map<dynamic, dynamic>?;

    return CelenganSnapshot(
      saldo: _parseInt(map['saldo']),
      terakhirMasuk: _parseInt(map['terakhir_masuk']),
      namaAnak: info != null ? (info['nama_anak'] ?? 'Azka').toString() : 'Azka',
      targetNama:
          info != null ? (info['target_nama'] ?? 'Sepeda Baru').toString() : 'Sepeda Baru',
      targetNominal: info != null ? _parseInt(info['target_nominal'], 100000) : 100000,
      isConnected: connected,
    );
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }
}

class DepositNotification {
  final String id;
  final int nominal;
  final int totalSaldo;
  final DateTime timestamp;
  final String namaAnak;

  const DepositNotification({
    required this.id,
    required this.nominal,
    required this.totalSaldo,
    required this.timestamp,
    required this.namaAnak,
  });
}

// ============================================================================
// DASHBOARD SCREEN (MAIN UI)
// ============================================================================
class DashboardCelenganScreen extends StatefulWidget {
  const DashboardCelenganScreen({super.key});

  /// Format Angka ke Rupiah (contoh: Rp 15.000)
  static String formatRupiah(int nominal) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(nominal);
  }

  @override
  State<DashboardCelenganScreen> createState() => _DashboardCelenganScreenState();
}

class _DashboardCelenganScreenState extends State<DashboardCelenganScreen>
    with SingleTickerProviderStateMixin {
  late Stream<CelenganSnapshot> _celenganStream;
  http.Client? _sseClient;
  Timer? _pollingTimer;

  // State Pelacak Saldo & Notifikasi Menabung
  int? _previousSaldo;
  DepositNotification? _activeNotification;
  final List<DepositNotification> _notificationHistory = [];
  Timer? _notificationDismissTimer;

  // Controller Animasi Banner Notifikasi
  late AnimationController _bannerAnimController;
  late Animation<Offset> _bannerSlideAnim;
  late Animation<double> _bannerFadeAnim;

  @override
  void initState() {
    super.initState();

    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _bannerSlideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeOutBack,
    ));

    _bannerFadeAnim = CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeIn,
    );

    _celenganStream = _buildRealtimeStream();
  }

  @override
  void dispose() {
    _notificationDismissTimer?.cancel();
    _pollingTimer?.cancel();
    _sseClient?.close();
    _bannerAnimController.dispose();
    super.dispose();
  }

  /// Membuat Stream Realtime dari Firebase Realtime Database
  Stream<CelenganSnapshot> _buildRealtimeStream() {
    try {
      if (Firebase.apps.isNotEmpty) {
        final rtdb = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: kFirebaseDatabaseUrl,
        );
        return rtdb.ref(kNodePath).onValue.map((event) {
          final data = event.snapshot.value;
          if (data is Map) {
            return CelenganSnapshot.fromMap(data, connected: true);
          }
          return CelenganSnapshot.fromMap(null, connected: true);
        });
      }
    } catch (e) {
      if (kDebugMode) print('Menggunakan Realtime HTTP Stream: $e');
    }

    return _createHttpStream();
  }

  /// Stream HTTP Polling Ringan untuk Fallback Multi-Platform
  Stream<CelenganSnapshot> _createHttpStream() {
    final controller = StreamController<CelenganSnapshot>.broadcast();
    final endpoint = Uri.parse('$kFirebaseDatabaseUrl/$kNodePath.json');

    void fetchLatest() async {
      try {
        final res = await http.get(endpoint).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200 && res.body != 'null') {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && !controller.isClosed) {
            controller.add(CelenganSnapshot.fromMap(decoded, connected: true));
          }
        }
      } catch (_) {
        if (!controller.isClosed) {
          controller.add(CelenganSnapshot.fromMap(null, connected: false));
        }
      }
    }

    // Panggil segera
    fetchLatest();

    // Polling periodik aman
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        fetchLatest();
      }
    });

    controller.onCancel = () {
      _pollingTimer?.cancel();
    };

    return controller.stream;
  }

  /// Menampilkan Notifikasi Ketika User/Anak Menabung Koin
  void _triggerDepositNotification({
    required int nominal,
    required int totalSaldo,
    required String namaAnak,
  }) {
    if (nominal <= 0) return;

    // Haptic feedback tactile (getaran mekanis saat koin masuk)
    HapticFeedback.mediumImpact();

    final notif = DepositNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nominal: nominal,
      totalSaldo: totalSaldo,
      timestamp: DateTime.now(),
      namaAnak: namaAnak,
    );

    setState(() {
      _activeNotification = notif;
      _notificationHistory.insert(0, notif);
      if (_notificationHistory.length > 50) {
        _notificationHistory.removeLast();
      }
    });

    _bannerAnimController.forward(from: 0.0);

    // Auto dismiss setelah 5 detik
    _notificationDismissTimer?.cancel();
    _notificationDismissTimer = Timer(const Duration(milliseconds: 5000), () {
      if (mounted) {
        _dismissActiveNotification();
      }
    });
  }

  void _dismissActiveNotification() {
    _bannerAnimController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _activeNotification = null;
        });
      }
    });
  }

  /// Deteksi Otomatis Koin Masuk dari Aliran Realtime
  void _onDataReceived(CelenganSnapshot data) {
    if (_previousSaldo != null && data.saldo > _previousSaldo! && _previousSaldo! > 0) {
      final nominalMasuk = data.terakhirMasuk > 0
          ? data.terakhirMasuk
          : (data.saldo - _previousSaldo!);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerDepositNotification(
            nominal: nominalMasuk,
            totalSaldo: data.saldo,
            namaAnak: data.namaAnak,
          );
        }
      });
    }
    _previousSaldo = data.saldo;
  }

  /// Simulasi Sinyal Sensor ESP32 (Atomic Increment ke Firebase)
  Future<void> _kirimSimulasiKoin(int nominal) async {
    try {
      final endpoint = Uri.parse('$kFirebaseDatabaseUrl/$kNodePath.json');
      final payload = jsonEncode({
        'saldo': {'.sv': {'increment': nominal}},
        'terakhir_masuk': nominal,
      });

      final response = await http.patch(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode == 200 && mounted) {
        // Notifikasi visual lokal langsung responsif
        _triggerDepositNotification(
          nominal: nominal,
          totalSaldo: (_previousSaldo ?? 0) + nominal,
          namaAnak: 'Azka',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: Text('Koneksi simulasi gagal: $e'),
          ),
        );
      }
    }
  }

  /// Dialog Ubah Target Tabungan & Nama Anak
  void _bukaDialogUbahTarget(CelenganSnapshot data) {
    final namaController = TextEditingController(text: data.namaAnak);
    final targetNamaController = TextEditingController(text: data.targetNama);
    final targetNominalController =
        TextEditingController(text: data.targetNominal.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: kHeritageForest),
              SizedBox(width: 8),
              Text(
                'Ubah Target Tabungan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Pemilik Celengan:'),
                const SizedBox(height: 6),
                TextField(
                  controller: namaController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Azka',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Barang Impian / Target:'),
                const SizedBox(height: 6),
                TextField(
                  controller: targetNamaController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Sepeda Baru',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Nominal Target (Rp):'),
                const SizedBox(height: 6),
                TextField(
                  controller: targetNominalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Contoh: 100000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kHeritageForest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final nominal = int.tryParse(targetNominalController.text.trim()) ?? 100000;
                final namaAnak = namaController.text.trim().isEmpty ? 'Azka' : namaController.text.trim();
                final targetNama = targetNamaController.text.trim().isEmpty ? 'Target Tabungan' : targetNamaController.text.trim();

                Navigator.pop(ctx);

                try {
                  final endpoint = Uri.parse('$kFirebaseDatabaseUrl/$kNodePath/info.json');
                  await http.patch(
                    endpoint,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'nama_anak': namaAnak,
                      'target_nama': targetNama,
                      'target_nominal': nominal,
                    }),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Target tabungan berhasil diperbarui!'),
                        backgroundColor: kHeritageForest,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menyimpan target: $e')),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  /// Modal Riwayat Notifikasi Menabung
  void _bukaRiwayatNotifikasiSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.notifications_active_rounded, color: kCoinBrass),
                          SizedBox(width: 8),
                          Text(
                            'Riwayat Notifikasi Menabung',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: kDeepSlate,
                            ),
                          ),
                        ],
                      ),
                      if (_notificationHistory.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _notificationHistory.clear();
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Bersihkan',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _notificationHistory.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_rounded, size: 56, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum Ada Notifikasi Menabung',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: kDeepSlate),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Setiap koin yang masuk ke celengan fisik akan tercatat otomatis di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _notificationHistory.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _notificationHistory[index];
                            final timeStr = DateFormat('HH:mm:ss').format(item.timestamp);
                            return ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.savings_rounded, color: kCoinBrass, size: 22),
                                ),
                              ),
                              title: Text(
                                '+${DashboardCelenganScreen.formatRupiah(item.nominal)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kHeritageForest,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                'Saldo menjadi ${DashboardCelenganScreen.formatRupiah(item.totalSaldo)} (oleh ${item.namaAnak})',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                              trailing: Text(
                                timeStr,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kHeritageForest.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_rounded,
                color: kHeritageForest,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Celengan Pintar IoT',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: kDeepSlate,
                  ),
                ),
                Text(
                  'Pemantau Tabungan Anak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 1. Tombol Navigasi ke Layar Analitik & Grafik (fl_chart)
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: kDeepSlate),
            tooltip: 'Tren & Analitik Tabungan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),

          // 2. Tombol Kontrol Perangkat Keras ESP32 (Buzzer & LED)
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: kDeepSlate),
            tooltip: 'Kontrol Perangkat Keras ESP32',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => HardwareControlSheet(
                  repository: HardwareFeedbackRepository(),
                ),
              );
            },
          ),

          // 3. Tombol Notifikasi Riwayat
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: kDeepSlate),
                tooltip: 'Riwayat Notifikasi Menabung',
                onPressed: _bukaRiwayatNotifikasiSheet,
              ),
              if (_notificationHistory.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: kCoinBrass,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${_notificationHistory.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<CelenganSnapshot>(
            stream: _celenganStream,
            builder: (context, snapshot) {
              // 1. Kondisi Loading
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(color: kHeritageForest),
                      SizedBox(height: 16),
                      Text(
                        'Menghubungkan ke Celengan Pintar...',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }

              // 2. Kondisi Error
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          'Koneksi Realtime Terkendala',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: kDeepSlate,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _celenganStream = _buildRealtimeStream();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kHeritageForest,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 3. Data Tersedia
              final data = snapshot.data ?? CelenganSnapshot.fromMap(null);
              _onDataReceived(data);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Bar Ringkas Realtime
                    _buildStatusBar(data.isConnected),

                    const SizedBox(height: 14),

                    // KARTU SALDO UTAMA (HERO)
                    _buildHeroSaldoCard(context, data),

                    const SizedBox(height: 18),

                    // KARTU SETORAN TERAKHIR (KOIN MASUK FISIK)
                    _buildSetoranTerakhirCard(context, data),

                    const SizedBox(height: 18),

                    // KARTU TARGET TABUNGAN DENGAN AKSI UBAH TARGET
                    _buildTargetTabunganCard(context, data),

                    const SizedBox(height: 22),

                    // SECTION SIMULASI SENSOR ESP32
                    _buildSimulasiSensorSection(context),
                  ],
                ),
              );
            },
          ),

          // ==========================================================
          // BANNER NOTIFIKASI MENABUNG (SLIDE-DOWN TOAST)
          // ==========================================================
          if (_activeNotification != null)
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: SlideTransition(
                position: _bannerSlideAnim,
                child: FadeTransition(
                  opacity: _bannerFadeAnim,
                  child: _CoinDepositBanner(
                    notification: _activeNotification!,
                    onDismiss: _dismissActiveNotification,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGET STATUS REALTIME BAR
  // --------------------------------------------------------------------------
  Widget _buildStatusBar(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: isConnected ? const Color(0xFF16A34A) : Colors.red),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Tersinkron Realtime dengan Firebase' : 'Mode Offline / Terputus',
            style: TextStyle(
              color: isConnected ? const Color(0xFF15803D) : const Color(0xFF991B1B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGET KARTU SALDO UTAMA (HERO)
  // R-31: Heritage Forest Solid Gradient untuk stabilitas finansial dan kontras WCAG AA.
  // --------------------------------------------------------------------------
  Widget _buildHeroSaldoCard(BuildContext context, CelenganSnapshot data) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            kHeritageForest,
            Color(0xFF065F46),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kHeritageForest.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL SALDO CELENGAN',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Milik ${data.namaAnak}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Animasi Angka Saldo yang Halus
          _AnimatedCounterText(
            value: data.saldo,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 12),
          Text(
            data.saldo == 0
                ? 'Belum ada saldo. Masukkan koin ke lubang celengan untuk memulai!'
                : 'Data terhubung langsung dengan sensor koin fisik ESP32.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGET KARTU SETORAN TERAKHIR
  // --------------------------------------------------------------------------
  Widget _buildSetoranTerakhirCard(BuildContext context, CelenganSnapshot data) {
    final theme = Theme.of(context);
    final hasDeposit = data.terakhirMasuk > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Center(
              child: Icon(
                Icons.monetization_on_rounded,
                color: kCoinBrass,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setoran Terakhir (Sensor Fisik)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                if (hasDeposit)
                  Text(
                    '+${DashboardCelenganScreen.formatRupiah(data.terakhirMasuk)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                else
                  Text(
                    'Belum ada koin masuk hari ini',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasDeposit ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              hasDeposit ? 'Tercatat' : 'Siap',
              style: TextStyle(
                color: hasDeposit ? const Color(0xFF166534) : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGET KARTU TARGET TABUNGAN
  // --------------------------------------------------------------------------
  Widget _buildTargetTabunganCard(BuildContext context, CelenganSnapshot data) {
    final theme = Theme.of(context);
    final progress = data.targetNominal > 0
        ? (data.saldo / data.targetNominal).clamp(0.0, 1.0)
        : 0.0;
    final isReached = data.saldo >= data.targetNominal;
    final sisa = data.targetNominal - data.saldo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReached ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_rounded, color: kHeritageForest, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Target: ${data.targetNama}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: kDeepSlate,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _bukaDialogUbahTarget(data),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: const [
                      Icon(Icons.edit_rounded, size: 14, color: kSageTeal),
                      SizedBox(width: 4),
                      Text(
                        'Ubah Target',
                        style: TextStyle(
                          color: kSageTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isReached ? const Color(0xFF10B981) : kSageTeal,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${DashboardCelenganScreen.formatRupiah(data.targetNominal)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Text(
                isReached
                    ? 'Target Tercapai! Selamat!'
                    : 'Kurang ${DashboardCelenganScreen.formatRupiah(sisa > 0 ? sisa : 0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isReached ? const Color(0xFF10B981) : const Color(0xFF64748B),
                  fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECTION SIMULASI SENSOR ESP32
  // R-31: Tombol berukuran minimal 48px untuk aksesibilitas jempol di layar mobile.
  // --------------------------------------------------------------------------
  Widget _buildSimulasiSensorSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors_rounded, color: kHeritageForest, size: 20),
              const SizedBox(width: 8),
              Text(
                'Simulasi Sinyal Koin ESP32',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: kHeritageForest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tekan tombol di bawah untuk menguji respons notifikasi realtime aplikasi:',
            style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _kirimSimulasiKoin(500),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text('+ Rp 500'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kHeritageForest,
                      side: const BorderSide(color: kHeritageForest, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _kirimSimulasiKoin(1000),
                    icon: const Icon(Icons.monetization_on_rounded, size: 18),
                    label: const Text('+ Rp 1.000'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kHeritageForest,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET FLOATING BANNER NOTIFIKASI MENABUNG
// R-31: Memberikan umpan balik langsung ketika koin fisik masuk ke celengan.
// ============================================================================
class _CoinDepositBanner extends StatelessWidget {
  final DepositNotification notification;
  final VoidCallback onDismiss;

  const _CoinDepositBanner({
    required this.notification,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kHeritageForest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.savings_rounded, color: kCoinBrass, size: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Koin Baru Masuk!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${DashboardCelenganScreen.formatRupiah(notification.nominal)}',
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Saldo kini ${DashboardCelenganScreen.formatRupiah(notification.totalSaldo)}. Terus semangat!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
              tooltip: 'Tutup Notifikasi',
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMASI ANGKA COUNTER HALUS
// ============================================================================
class _AnimatedCounterText extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _AnimatedCounterText({
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedVal, child) {
        return Text(
          DashboardCelenganScreen.formatRupiah(animatedVal.round()),
          style: style,
        );
      },
    );
  }
}

// ============================================================================
// PULSING DOT STATUS REALTIME
// ============================================================================
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(
        Tween<double>(begin: 0.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

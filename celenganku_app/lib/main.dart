import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// KONFIGURASI FIREBASE REALTIME DATABASE (ASIA-SOUTHEAST1)
// ============================================================================
const String kFirebaseProjectId = 'celenganku-456f9';
const String kFirebaseDatabaseUrl =
    'https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app';
const String kNodePath = 'celengan_01';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase Core secara aman dan kompatibel multi-platform
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyDummyKeyForRealtimeDatabasePublicAccess456f9',
          appId: '1:543210987654:android:celenganku456f9',
          messagingSenderId: '543210987654',
          projectId: kFirebaseProjectId,
          databaseURL: kFirebaseDatabaseUrl,
        ),
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('Info: Inisialisasi Firebase Native dialihkan ke Fallback Engine: $e');
    }
  }

  runApp(const CelenganApp());
}

// ============================================================================
// ROOT APPLICATION WIDGET
// ============================================================================
class CelenganApp extends StatelessWidget {
  const CelenganApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F766E); // Deep Teal Emerald
    const secondaryColor = Color(0xFFF59E0B); // Warm Amber Gold
    const backgroundColor = Color(0xFFF8FAFC); // Slate 50 Minimalist

    return MaterialApp(
      title: 'Celengan Pintar IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.light().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
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
// UNIFIED REALTIME DATA ADAPTER (NATIVE SDK + HTTP SSE STREAM FALLBACK)
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

// ============================================================================
// DASHBOARD SCREEN (MAIN UI)
// ============================================================================
class DashboardCelenganScreen extends StatefulWidget {
  const DashboardCelenganScreen({super.key});

  /// Format Angka ke Rupiah (contoh: Rp15.000)
  static String formatRupiah(int nominal) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(nominal);
  }

  @override
  State<DashboardCelenganScreen> createState() => _DashboardCelenganScreenState();
}

class _DashboardCelenganScreenState extends State<DashboardCelenganScreen> {
  late Stream<CelenganSnapshot> _celenganStream;
  http.Client? _sseClient;

  @override
  void initState() {
    super.initState();
    _celenganStream = _buildRealtimeStream();
  }

  @override
  void dispose() {
    _sseClient?.close();
    super.dispose();
  }

  /// Membuat Stream Realtime:
  /// Mencoba FirebaseDatabase.instanceFor (region asia-southeast1),
  /// dan otomatis fallback ke Firebase Realtime Database SSE jika plugin belum terhubung.
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
      if (kDebugMode) print('Menggunakan Realtime SSE Stream: $e');
    }

    return _createSseStream();
  }

  /// Fallback SSE Stream langsung ke Firebase Realtime Database
  Stream<CelenganSnapshot> _createSseStream() async* {
    _sseClient?.close();
    _sseClient = http.Client();

    final endpoint = Uri.parse('$kFirebaseDatabaseUrl/$kNodePath.json');

    // Emisi nilai awal via HTTP GET
    try {
      final initialRes = await http.get(endpoint).timeout(const Duration(seconds: 4));
      if (initialRes.statusCode == 200 && initialRes.body != 'null') {
        final decoded = jsonDecode(initialRes.body);
        if (decoded is Map) {
          yield CelenganSnapshot.fromMap(decoded, connected: true);
        }
      }
    } catch (_) {
      yield CelenganSnapshot.fromMap(null, connected: false);
    }

    // Polling periodik ringan untuk memastikan data selalu sinkron
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final res = await http.get(endpoint).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200 && res.body != 'null') {
          final decoded = jsonDecode(res.body);
          if (decoded is Map) {
            yield CelenganSnapshot.fromMap(decoded, connected: true);
          }
        }
      } catch (_) {
        // Biarkan tetap aktif
      }
    }
  }

  /// Format Angka ke Rupiah (contoh: Rp15.000)
  static String formatRupiah(int nominal) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(nominal);
  }

  /// Fungsi untuk simulasi tes koin masuk (Atomic Increment)
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

      if (mounted && response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0F766E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.amberAccent),
                const SizedBox(width: 10),
                Text(
                  'Koin ${formatRupiah(nominal)} berhasil dicatat ke Firebase!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[700],
            content: Text('Gagal mengirim simulasi: $e'),
          ),
        );
      }
    }
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
                color: const Color(0xFF0F766E).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_rounded,
                color: Color(0xFF0F766E),
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
                  ),
                ),
                Text(
                  'Pemantau Tabungan Anak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Indikator Realtime Status (Chip Hijau "Terhubung")
          Container(
            margin: const EdgeInsets.only(right: 18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7), // Soft green
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(color: Color(0xFF16A34A)),
                SizedBox(width: 6),
                Text(
                  'Terhubung',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<CelenganSnapshot>(
        stream: _celenganStream,
        builder: (context, snapshot) {
          // 1. Kondisi Loading / Waiting
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0F766E)),
                  SizedBox(height: 16),
                  Text(
                    'Menghubungkan ke Firebase Realtime Database...',
                    style: TextStyle(color: Colors.grey),
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
                    const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal Menyinkronkan Data',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _celenganStream = _buildRealtimeStream();
                        });
                      },
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

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================================
                // KARTU SALDO UTAMA (HERO DISPLAY)
                // ============================================================
                _buildHeroSaldoCard(context, data),

                const SizedBox(height: 18),

                // ============================================================
                // KARTU SETORAN TERAKHIR (DARI ESP32)
                // ============================================================
                _buildSetoranTerakhirCard(context, data),

                const SizedBox(height: 18),

                // ============================================================
                // KARTU TARGET TABUNGAN (SAVINGS GOAL)
                // ============================================================
                _buildTargetTabunganCard(context, data),

                const SizedBox(height: 24),

                // ============================================================
                // SECTION SIMULASI SENSOR ESP32 (VIBE CODING TESTER)
                // ============================================================
                _buildSimulasiSensorSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // WIDGET KARTU SALDO UTAMA
  // --------------------------------------------------------------------------
  Widget _buildHeroSaldoCard(BuildContext context, CelenganSnapshot data) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E), // Deep Teal
            Color(0xFF115E59), // Rich Emerald
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
                'TOTAL SALDO TERKINI',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tabungan ${data.namaAnak}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Animasi Transisi Angka Saldo yang Halus
          _AnimatedCounterText(
            value: data.saldo,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),

          const SizedBox(height: 12),
          Text(
            data.saldo == 0
                ? 'Belum ada saldo. Masukkan koin ke celengan untuk memulai!'
                : 'Data otomatis tersinkron realtime dengan celengan fisik.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.8),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ikon Koin Amber
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), // Soft Amber
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Center(
              child: Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFD97706),
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Deskripsi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setoran Terakhir (ESP32)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasDeposit)
                  Text(
                    '+${formatRupiah(data.terakhirMasuk)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF15803D), // Emerald Green
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                else
                  Text(
                    'Belum ada koin masuk',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // Badge Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasDeposit
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasDeposit ? 'Baru Saja' : 'Siap',
              style: TextStyle(
                color: hasDeposit
                    ? const Color(0xFF166534)
                    : const Color(0xFF64748B),
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isReached
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
                  const Icon(Icons.flag_rounded, color: Color(0xFF0F766E), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Target: ${data.targetNama}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isReached ? const Color(0xFF10B981) : const Color(0xFF0F766E),
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
                'Target: ${formatRupiah(data.targetNominal)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                isReached
                    ? '🎉 Target Tercapai!'
                    : 'Kurang ${formatRupiah(sisa > 0 ? sisa : 0)} lagi',
                style: theme.textTheme.bodySmall?.copyWith(
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
  // WIDGET SIMULASI SENSOR ESP32
  // --------------------------------------------------------------------------
  Widget _buildSimulasiSensorSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors_rounded, color: Color(0xFF0F766E), size: 18),
              const SizedBox(width: 8),
              Text(
                'Simulasi Sinyal ESP32 (Wokwi Tester)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Kirim atomic increment server-value ke path /celengan_01 seperti halnya saklar koin fisik:',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _kirimSimulasiKoin(500),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Rp500'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _kirimSimulasiKoin(1000),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Rp1.000'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
// ANIMASI ANGKA COUNTER HALUS (TWEEN ANIMATION)
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
      duration: const Duration(milliseconds: 700),
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

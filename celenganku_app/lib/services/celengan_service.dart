  import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/celengan_data.dart';

enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  demoMode,
}

class CelenganService {
  static final CelenganService _instance = CelenganService._internal();
  factory CelenganService() => _instance;
  CelenganService._internal();

  // URL default Firebase Realtime Database
  String _databaseUrl =
      'https://celenganku-456f9-default-rtdb.asia-southeast1.firebasedatabase.app';
  String _deviceId = 'celengan_01';

  final _dataController = StreamController<CelenganData>.broadcast();
  Stream<CelenganData> get stream => _dataController.stream;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  CelenganData _currentData = CelenganData.initialDemo();
  CelenganData get currentData => _currentData;

  ConnectionStatus _status = ConnectionStatus.demoMode;
  ConnectionStatus get status => _status;

  http.Client? _sseClient;
  Timer? _pollingTimer;
  bool _isDisposed = false;

  String get databaseUrl => _databaseUrl;
  String get deviceId => _deviceId;

  void configure({required String databaseUrl, required String deviceId}) {
    _databaseUrl = databaseUrl.replaceAll(RegExp(r'/+$'), '');
    _deviceId = deviceId.trim();
    reconnect();
  }

  void start() {
    _isDisposed = false;
    _dataController.add(_currentData);
    _statusController.add(_status);

    if (_databaseUrl.contains('demo') || _databaseUrl.contains('[PROJECT-ID]')) {
      _setStatus(ConnectionStatus.demoMode);
    } else {
      _connectSse();
    }
  }

  void reconnect() {
    _sseClient?.close();
    _pollingTimer?.cancel();
    start();
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
  }

  /// Menghubungkan ke Firebase Realtime Database via Server-Sent Events (SSE)
  /// Header: Accept: text/event-stream
  /// Firebase akan mengirim event 'put' atau 'patch' setiap ada perubahan data.
  Future<void> _connectSse() async {
    _setStatus(ConnectionStatus.connecting);
    _sseClient?.close();
    _sseClient = http.Client();

    final endpoint = Uri.parse('$_databaseUrl/$_deviceId.json');

    try {
      final request = http.Request('GET', endpoint);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _sseClient!.send(request);

      if (response.statusCode == 200) {
        _setStatus(ConnectionStatus.connected);

        response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              _handleSseLine,
              onError: (err) {
                if (kDebugMode) print('Firebase SSE Error: $err');
                _fallbackToPolling();
              },
              onDone: () {
                if (!_isDisposed) {
                  _fallbackToPolling();
                }
              },
              cancelOnError: false,
            );
      } else {
        _fallbackToPolling();
      }
    } catch (e) {
      if (kDebugMode) print('Koneksi Firebase gagal: $e');
      _fallbackToPolling();
    }
  }

  String _currentEventType = '';
  void _handleSseLine(String line) {
    if (line.startsWith('event: ')) {
      _currentEventType = line.substring(7).trim();
    } else if (line.startsWith('data: ')) {
      final dataStr = line.substring(6).trim();
      if (dataStr == 'null' || dataStr.isEmpty) return;

      try {
        final decoded = jsonDecode(dataStr);
        if (_currentEventType == 'put') {
          final path = decoded['path'] as String? ?? '/';
          final data = decoded['data'];

          if (path == '/' && data is Map) {
            _updateData(CelenganData.fromMap(data));
          } else if (path.isEmpty || path == '/') {
            fetchLatest();
          } else {
            // Perubahan sub-node, fetch ulang snapshot penuh
            fetchLatest();
          }
        } else if (_currentEventType == 'patch') {
          fetchLatest();
        }
      } catch (e) {
        if (kDebugMode) print('Gagal mem-parse SSE payload: $e');
      }
    }
  }

  /// Fallback mode: Melakukan HTTP GET periodik jika SSE terputus
  void _fallbackToPolling() {
    _setStatus(ConnectionStatus.connecting);
    _pollingTimer?.cancel();
    fetchLatest();

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchLatest();
    });
  }

  /// Mengambil data celengan terbaru dari Firebase REST API
  Future<void> fetchLatest() async {
    try {
      final endpoint = Uri.parse('$_databaseUrl/$_deviceId.json');
      final res = await http.get(endpoint).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && res.body != 'null') {
        final map = jsonDecode(res.body);
        if (map is Map) {
          _updateData(CelenganData.fromMap(map));
          _setStatus(ConnectionStatus.connected);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Gagal fetch data: $e');
      if (_status != ConnectionStatus.demoMode) {
        _setStatus(ConnectionStatus.disconnected);
      }
    }
  }

  /// Simulasi koin masuk (baik ke Firebase nyata via HTTP PATCH atomic increment atau lokal demo)
  Future<void> insertCoin({required int nominal}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txId = '-OAx${now.toRadixString(36)}';

    if (_status == ConnectionStatus.demoMode) {
      // Update lokal untuk simulasi demo
      final riwayatBaru = [
        RiwayatTransaksi(id: txId, nominal: nominal, timestamp: now),
        ..._currentData.riwayat,
      ];
      final dataBaru = CelenganData(
        info: _currentData.info,
        saldo: _currentData.saldo + nominal,
        terakhirMasuk: nominal,
        riwayat: riwayatBaru,
      );
      _updateData(dataBaru);
      return;
    }

    // Jika terhubung ke Firebase, kirim atomic increment persis seperti ESP32
    try {
      final endpoint = Uri.parse('$_databaseUrl/$_deviceId.json');
      final payload = {
        'saldo': {'.sv': {'increment': nominal}},
        'terakhir_masuk': nominal,
        'riwayat/$txId': {
          'nominal': nominal,
          'timestamp': now,
        },
      };

      await http.patch(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      await fetchLatest();
    } catch (e) {
      if (kDebugMode) print('Gagal mengirim insertCoin: $e');
    }
  }

  /// Update target tabungan
  Future<void> updateTarget({
    required String namaAnak,
    required String targetNama,
    required int targetNominal,
  }) async {
    if (_status == ConnectionStatus.demoMode) {
      final newInfo = CelenganInfo(
        namaAnak: namaAnak,
        targetNominal: targetNominal,
        targetNama: targetNama,
      );
      final dataBaru = CelenganData(
        info: newInfo,
        saldo: _currentData.saldo,
        terakhirMasuk: _currentData.terakhirMasuk,
        riwayat: _currentData.riwayat,
      );
      _updateData(dataBaru);
      return;
    }

    try {
      final endpoint = Uri.parse('$_databaseUrl/$_deviceId/info.json');
      final payload = {
        'nama_anak': namaAnak,
        'target_nama': targetNama,
        'target_nominal': targetNominal,
      };
      await http.put(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      await fetchLatest();
    } catch (e) {
      if (kDebugMode) print('Gagal update target: $e');
    }
  }

  /// Reset saldo (Berguna untuk pengujian)
  Future<void> resetSaldo() async {
    if (_status == ConnectionStatus.demoMode) {
      final dataBaru = CelenganData(
        info: _currentData.info,
        saldo: 0,
        terakhirMasuk: 0,
        riwayat: const [],
      );
      _updateData(dataBaru);
      return;
    }

    try {
      final endpoint = Uri.parse('$_databaseUrl/$_deviceId.json');
      final payload = {
        'saldo': 0,
        'terakhir_masuk': 0,
        'riwayat': null,
      };
      await http.patch(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      await fetchLatest();
    } catch (e) {
      if (kDebugMode) print('Gagal reset saldo: $e');
    }
  }

  void _updateData(CelenganData newData) {
    _currentData = newData;
    if (!_dataController.isClosed) {
      _dataController.add(_currentData);
    }
  }

  void dispose() {
    _isDisposed = true;
    _sseClient?.close();
    _pollingTimer?.cancel();
    _dataController.close();
    _statusController.close();
  }
}

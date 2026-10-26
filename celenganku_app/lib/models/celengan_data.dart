class CelenganInfo {
  final String namaAnak;
  final int targetNominal;
  final String targetNama;

  const CelenganInfo({
    required this.namaAnak,
    required this.targetNominal,
    required this.targetNama,
  });

  factory CelenganInfo.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const CelenganInfo(
        namaAnak: 'Anak Hebat',
        targetNominal: 100000,
        targetNama: 'Target Impian',
      );
    }
    return CelenganInfo(
      namaAnak: (map['nama_anak'] ?? 'Anak Hebat').toString(),
      targetNominal: _parseInt(map['target_nominal'], 100000),
      targetNama: (map['target_nama'] ?? 'Target Impian').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama_anak': namaAnak,
      'target_nominal': targetNominal,
      'target_nama': targetNama,
    };
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class RiwayatTransaksi {
  final String id;
  final int nominal;
  final int timestamp;

  const RiwayatTransaksi({
    required this.id,
    required this.nominal,
    required this.timestamp,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory RiwayatTransaksi.fromEntry(String key, Map<dynamic, dynamic> map) {
    return RiwayatTransaksi(
      id: key,
      nominal: CelenganInfo._parseInt(map['nominal'], 0),
      timestamp: CelenganInfo._parseInt(
        map['timestamp'],
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nominal': nominal,
      'timestamp': timestamp,
    };
  }
}

class CelenganData {
  final CelenganInfo info;
  final int saldo;
  final int terakhirMasuk;
  final List<RiwayatTransaksi> riwayat;

  const CelenganData({
    required this.info,
    required this.saldo,
    required this.terakhirMasuk,
    required this.riwayat,
  });

  double get persentaseTarget {
    if (info.targetNominal <= 0) return 1.0;
    final progress = saldo / info.targetNominal;
    return progress.clamp(0.0, 1.0);
  }

  int get sisaTarget {
    final sisa = info.targetNominal - saldo;
    return sisa > 0 ? sisa : 0;
  }

  bool get sudahTercapai => saldo >= info.targetNominal;

  factory CelenganData.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return CelenganData(
        info: const CelenganInfo(
          namaAnak: 'Azka',
          targetNominal: 100000,
          targetNama: 'Sepeda Baru',
        ),
        saldo: 0,
        terakhirMasuk: 0,
        riwayat: const [],
      );
    }

    final infoMap = map['info'] as Map<dynamic, dynamic>?;
    final riwayatRaw = map['riwayat'] as Map<dynamic, dynamic>?;

    final riwayatList = <RiwayatTransaksi>[];
    if (riwayatRaw != null) {
      riwayatRaw.forEach((key, val) {
        if (val is Map) {
          riwayatList.add(RiwayatTransaksi.fromEntry(key.toString(), val));
        }
      });
      // Urutkan transaksi terbaru di atas
      riwayatList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    return CelenganData(
      info: CelenganInfo.fromMap(infoMap),
      saldo: CelenganInfo._parseInt(map['saldo'], 0),
      terakhirMasuk: CelenganInfo._parseInt(map['terakhir_masuk'], 0),
      riwayat: riwayatList,
    );
  }

  static CelenganData initialDemo() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return CelenganData(
      info: const CelenganInfo(
        namaAnak: 'Azka',
        targetNominal: 100000,
        targetNama: 'Sepeda Baru',
      ),
      saldo: 15000,
      terakhirMasuk: 1000,
      riwayat: [
        RiwayatTransaksi(
          id: '-OAxYz789012',
          nominal: 500,
          timestamp: now - 180000,
        ),
        RiwayatTransaksi(
          id: '-OAxYz123456',
          nominal: 1000,
          timestamp: now - 480000,
        ),
      ],
    );
  }
}

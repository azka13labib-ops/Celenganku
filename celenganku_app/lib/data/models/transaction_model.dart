import 'package:intl/intl.dart';

enum TransactionType {
  koinOtomatis,
  setorManual,
  unknown;

  static TransactionType fromString(String? val) {
    switch (val) {
      case 'koin_otomatis':
        return TransactionType.koinOtomatis;
      case 'setor_manual':
        return TransactionType.setorManual;
      default:
        return TransactionType.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case TransactionType.koinOtomatis:
        return 'koin_otomatis';
      case TransactionType.setorManual:
        return 'setor_manual';
      case TransactionType.unknown:
        return 'unknown';
    }
  }
}

class TransactionModel {
  final String id;
  final int nominal;
  final String uid;
  final TransactionType tipe;
  final double? beratGram;
  final DateTime timestamp;
  final String? catatan;

  const TransactionModel({
    required this.id,
    required this.nominal,
    required this.uid,
    required this.tipe,
    this.beratGram,
    required this.timestamp,
    this.catatan,
  });

  factory TransactionModel.fromMap(String id, Map<dynamic, dynamic> map) {
    int parsedNominal = 0;
    final nomVal = map['nominal'];
    if (nomVal is int) parsedNominal = nomVal;
    if (nomVal is double) parsedNominal = nomVal.toInt();
    if (nomVal is String) parsedNominal = int.tryParse(nomVal) ?? 0;

    double? parsedBerat;
    final beratVal = map['berat_gram'];
    if (beratVal is num) parsedBerat = beratVal.toDouble();

    DateTime parsedDate = DateTime.now();
    final tsVal = map['timestamp'];
    if (tsVal is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(tsVal);
    } else if (tsVal is String) {
      final parsedInt = int.tryParse(tsVal);
      if (parsedInt != null) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(parsedInt);
      }
    }

    return TransactionModel(
      id: id,
      nominal: parsedNominal,
      uid: (map['uid'] ?? 'anon').toString(),
      tipe: TransactionType.fromString(map['tipe']?.toString()),
      beratGram: parsedBerat,
      timestamp: parsedDate,
      catatan: map['catatan']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nominal': nominal,
      'uid': uid,
      'tipe': tipe.toDbString(),
      if (beratGram != null) 'berat_gram': beratGram,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (catatan != null) 'catatan': catatan,
    };
  }

  String get formattedNominal {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(nominal);
  }
}

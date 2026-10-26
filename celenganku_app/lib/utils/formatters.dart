import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String rupiah(num amount) {
    return _currencyFormat.format(amount);
  }

  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24 && dateTime.day == now.day) {
      final timeStr = DateFormat('HH:mm').format(dateTime);
      return 'Hari ini, $timeStr';
    } else if (difference.inDays < 2 && dateTime.day == now.day - 1) {
      final timeStr = DateFormat('HH:mm').format(dateTime);
      return 'Kemarin, $timeStr';
    } else {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dateTime);
    }
  }

  static String persentase(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}

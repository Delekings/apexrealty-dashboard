// lib/core/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  static final _naira = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );

  static final _nairaCompact = NumberFormat.compactCurrency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 1,
  );

  static String naira(num? amount) =>
      amount == null ? '—' : _naira.format(amount);

  /// e.g. ₦184M
  static String nairaCompact(num? amount) =>
      amount == null ? '—' : _nairaCompact.format(amount);

  static String date(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy').format(d);

  static String dateTime(DateTime? d) =>
      d == null ? '—' : DateFormat('d MMM yyyy · h:mm a').format(d);

  /// Quick "2hrs ago" style
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}hr${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('d MMM').format(d);
  }
}

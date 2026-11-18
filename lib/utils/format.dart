import 'package:intl/intl.dart';

/// Shared formatting helpers and constants.

final NumberFormat _rm = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);

/// Formats a number as Malaysian Ringgit, e.g. RM 1,500.00
String rm(num value) => _rm.format(value);

/// Date stored in Firestore as 'yyyy-MM-dd' so it is easy to compare and query.
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String todayKey() => dateKey(DateTime.now());

/// 'Wed, 18 Nov 2026'
String prettyDate(String key) {
  try {
    return DateFormat('EEE, d MMM yyyy').format(DateTime.parse(key));
  } catch (_) {
    return key;
  }
}

/// Fixed time slots a hall can be booked for.
const List<String> timeSlots = [
  'Morning (8:00 AM - 12:00 PM)',
  'Afternoon (1:00 PM - 5:00 PM)',
  'Evening (6:00 PM - 11:00 PM)',
];

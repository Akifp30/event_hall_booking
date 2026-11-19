import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/format.dart';

/// Snapshot of an add-on at the moment it was booked.
class BookedAddon {
  final String id;
  final String name;
  final double price;

  const BookedAddon({required this.id, required this.name, required this.price});

  factory BookedAddon.fromMap(Map<String, dynamic> m) => BookedAddon(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        price: (m['price'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'price': price};
}

/// A hall booking. Stored in the `bookings` collection.
class Booking {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String hallId;
  final String hallName;
  final String date; // yyyy-MM-dd
  final String timeSlot;
  final List<BookedAddon> addons;
  final double hallPrice;
  final double totalPrice;
  final String status; // 'confirmed' | 'cancelled'
  final double amountPaid;
  final String paymentMethod;
  final String transactionId;
  final DateTime? createdAt;

  const Booking({
    this.id = '',
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.hallId,
    required this.hallName,
    required this.date,
    required this.timeSlot,
    required this.addons,
    required this.hallPrice,
    required this.totalPrice,
    this.status = 'confirmed',
    this.amountPaid = 0,
    this.paymentMethod = '',
    this.transactionId = '',
    this.createdAt,
  });

  bool get isCancelled => status == 'cancelled';
  double get balance => totalPrice - amountPaid;
  bool get needsPayment => !isCancelled && balance > 0.009;

  String get paymentLabel {
    if (isCancelled) return amountPaid > 0 ? 'Refund ${rm(amountPaid)}' : 'Not paid';
    if (amountPaid <= 0) return 'Unpaid';
    if (balance > 0.009) return 'Balance due ${rm(balance)}';
    if (balance < -0.009) return 'Paid - refund ${rm(-balance)} due';
    return 'Paid';
  }

  /// Upcoming = not cancelled and the event date is today or later.
  bool get isUpcoming => !isCancelled && date.compareTo(todayKey()) >= 0;

  String get statusLabel => isCancelled ? 'Cancelled' : (isUpcoming ? 'Upcoming' : 'Completed');

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    final ts = m['createdAt'];
    return Booking(
      id: doc.id,
      userId: (m['userId'] ?? '') as String,
      userName: (m['userName'] ?? '') as String,
      userEmail: (m['userEmail'] ?? '') as String,
      hallId: (m['hallId'] ?? '') as String,
      hallName: (m['hallName'] ?? '') as String,
      date: (m['date'] ?? '') as String,
      timeSlot: (m['timeSlot'] ?? '') as String,
      addons: ((m['addons'] ?? const []) as List)
          .map((e) => BookedAddon.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hallPrice: (m['hallPrice'] as num?)?.toDouble() ?? 0,
      totalPrice: (m['totalPrice'] as num?)?.toDouble() ?? 0,
      status: (m['status'] ?? 'confirmed') as String,
      amountPaid: (m['amountPaid'] as num?)?.toDouble() ?? 0,
      paymentMethod: (m['paymentMethod'] ?? '') as String,
      transactionId: (m['transactionId'] ?? '') as String,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'hallId': hallId,
        'hallName': hallName,
        'date': date,
        'timeSlot': timeSlot,
        'addons': addons.map((a) => a.toMap()).toList(),
        'hallPrice': hallPrice,
        'totalPrice': totalPrice,
        'status': status,
    'amountPaid' : amountPaid,
    'paymentMethod' : paymentMethod,
    'transactionId' : transactionId,
      };
}

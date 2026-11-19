import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/addon.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/hall.dart';
import '../utils/format.dart';

/// All database reads/writes for the app (Cloud Firestore).
///
/// Collections (database: event_hall_booking):
///   users     - account profile + role
///   halls     - hall information
///   addons    - add-on services
///   bookings  - hall bookings (incl. demo payment info)
///   notifications - in-app notices for users and admins
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _halls => _db.collection('halls');
  CollectionReference<Map<String, dynamic>> get _addons => _db.collection('addons');
  CollectionReference<Map<String, dynamic>> get _bookings => _db.collection('bookings');
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');

  // ---------------------------------------------------------------- Halls

  Stream<List<Hall>> hallsStream({bool activeOnly = false}) {
    return _halls.orderBy('name').snapshots().map((s) => s.docs
        .map(Hall.fromDoc)
        .where((h) => !activeOnly || h.isActive)
        .toList());
  }

  Stream<Hall?> hallStream(String id) =>
      _halls.doc(id).snapshots().map((d) => d.exists ? Hall.fromDoc(d) : null);

  Future<Hall?> getHall(String id) async {
    final d = await _halls.doc(id).get();
    return d.exists ? Hall.fromDoc(d) : null;
  }

  Future<void> saveHall(Hall hall) async {
    if (hall.id.isEmpty) {
      await _halls.add({...hall.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _halls.doc(hall.id).update(hall.toMap());
    }
  }

  Future<void> deleteHall(String id) => _halls.doc(id).delete();

  // --------------------------------------------------------------- Add-ons

  Stream<List<Addon>> addonsStream() =>
      _addons.orderBy('name').snapshots().map((s) => s.docs.map(Addon.fromDoc).toList());

  // -------------------------------------------------------------- Bookings

  /// Time slots already taken for a hall on a date (cancelled bookings are ignored).
  Future<Set<String>> bookedSlots(String hallId, String date, {String? excludeBookingId}) async {
    final q = await _bookings
        .where('hallId', isEqualTo: hallId)
        .where('date', isEqualTo: date)
        .get();
    return q.docs
        .where((d) => d.id != excludeBookingId && d.data()['status'] != 'cancelled')
        .map((d) => (d.data()['timeSlot'] ?? '') as String)
        .toSet();
  }

  Stream<Booking?> bookingStream(String id) =>
      _bookings.doc(id).snapshots().map((d) => d.exists ? Booking.fromDoc(d) : null);

  /// Creates a booking and notifies the user and admins. Returns the new id.
  Future<String> createBooking(Booking b) async {
    final ref = await _bookings.add({...b.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    await notify(
      userId: b.userId,
      title: 'Booking confirmed',
      body: '${b.hallName} on ${prettyDate(b.date)}, ${b.timeSlot}.',
      type: 'booking',
      bookingId: ref.id,
    );
    await notify(
      userId: adminsInbox,
      title: 'New booking',
      body: '${b.userName} booked ${b.hallName} on ${prettyDate(b.date)}.',
      type: 'booking',
      bookingId: ref.id,
    );
    return ref.id;
  }

  /// User edits: date, time, add-ons and the recalculated price.
  Future<void> updateBooking(Booking b) async {
    await _bookings.doc(b.id).update({
      'date': b.date,
      'timeSlot': b.timeSlot,
      'addons': b.addons.map((a) => a.toMap()).toList(),
      'hallPrice': b.hallPrice,
      'totalPrice': b.totalPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await notify(
      userId: b.userId,
      title: 'Booking updated',
      body: '${b.hallName}: ${prettyDate(b.date)}, ${b.timeSlot}. New total ${rm(b.totalPrice)}.',
      type: 'booking',
      bookingId: b.id,
    );
    await notify(
      userId: adminsInbox,
      title: 'Booking updated by customer',
      body: '${b.userName} changed their booking for ${b.hallName}.',
      type: 'booking',
      bookingId: b.id,
    );
  }

  /// Admin edits: reschedule date / time.
  Future<void> rescheduleBooking(Booking b, {required String date, required String timeSlot}) async {
    await _bookings.doc(b.id).update({
      'date': date,
      'timeSlot': timeSlot,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await notify(
      userId: b.userId,
      title: 'Booking rescheduled',
      body: 'Your booking for ${b.hallName} has been moved to ${prettyDate(date)}, $timeSlot.',
      type: 'reschedule',
      bookingId: b.id,
    );
  }

  Future<void> cancelBooking(Booking b, {String by = 'user'}) async {
    await _bookings.doc(b.id).update({
      'status': 'cancelled',
      'cancelledBy': by,
      'refundAmount': b.amountPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final refund = b.amountPaid > 0 ? ' A refund of ${rm(b.amountPaid)} will be processed.' : '';
    await notify(
      userId: b.userId,
      title: by == 'admin' ? 'Booking cancelled by admin' : 'Booking cancelled',
      body: 'Your booking for ${b.hallName} on ${prettyDate(b.date)} was cancelled.$refund',
      type: 'cancel',
      bookingId: b.id,
    );
    if (by != 'admin') {
      await notify(
        userId: adminsInbox,
        title: 'Booking cancelled by customer',
        body: '${b.userName} cancelled ${b.hallName} on ${prettyDate(b.date)}.',
        type: 'cancel',
        bookingId: b.id,
      );
    }
  }

  /// Demo payment: records the amount paid and returns a transaction id.
  /// No real money is charged.
  Future<String> recordPayment(Booking b, {required String method, required double amount}) async {
    final txn = 'TXN${DateTime.now().millisecondsSinceEpoch}';
    await _bookings.doc(b.id).update({
      'amountPaid': FieldValue.increment(amount),
      'paymentMethod': method,
      'transactionId': txn,
      'paidAt': FieldValue.serverTimestamp(),
    });
    await notify(
      userId: b.userId,
      title: 'Payment received',
      body: '${rm(amount)} paid via $method for ${b.hallName}. Ref: $txn',
      type: 'payment',
      bookingId: b.id,
    );
    await notify(
      userId: adminsInbox,
      title: 'Payment received',
      body: '${b.userName} paid ${rm(amount)} for ${b.hallName}.',
      type: 'payment',
      bookingId: b.id,
    );
    return txn;
  }

  Stream<List<Booking>> userBookings(String uid) => _bookings
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Booking.fromDoc).toList());

  Stream<List<Booking>> allBookings() => _bookings.snapshots().map((s) {
    final list = s.docs.map(Booking.fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  });

  // ----------------------------------------------------------------- Users

  Stream<List<AppUser>> usersStream() => _users.snapshots().map((s) {
    final list = s.docs.map(AppUser.fromDoc).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  });

  Future<void> updateUser(String uid, Map<String, dynamic> data) => _users.doc(uid).update(data);

  // --------------------------------------------------------- Notifications

  /// Shared inbox id for notices shown to all admins.
  static const String adminsInbox = 'admins';

  Future<void> notify({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
    String bookingId = '',
  }) async {
    try {
      await _notifications.add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'bookingId': bookingId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A failed notice must never block the booking itself.
    }
  }

  Stream<List<AppNotification>> notificationsStream(String userId) => _notifications
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) {
    final list = s.docs.map(AppNotification.fromDoc).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
    return list;
  });

  Future<void> markNotificationRead(String id) => _notifications.doc(id).update({'read': true});

  Future<void> markAllNotificationsRead(List<AppNotification> items) async {
    final batch = _db.batch();
    for (final n in items.where((n) => !n.read)) {
      batch.update(_notifications.doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  // ----------------------------------------------------------- Sample data

  /// Loads demo halls and add-ons if the collections are empty.
  Future<String> seedSampleData() async {
    final batch = _db.batch();
    var added = 0;

    if ((await _halls.limit(1).get()).docs.isEmpty) {
      for (final h in _sampleHalls) {
        batch.set(_halls.doc(), {...h.toMap(), 'createdAt': FieldValue.serverTimestamp()});
        added++;
      }
    }
    if ((await _addons.limit(1).get()).docs.isEmpty) {
      for (final a in _sampleAddons) {
        batch.set(_addons.doc(), a);
        added++;
      }
    }
    if (added == 0) return 'Sample data already exists.';
    await batch.commit();
    return 'Added $added sample records.';
  }

  static const List<Hall> _sampleHalls = [
    Hall(
      name: 'Grand Ballroom',
      location: 'Level 2, Menara Seri, Kuala Lumpur',
      capacity: 500,
      basePrice: 8500,
      amenities: ['Stage', 'Air-conditioning', 'Wi-Fi', 'Parking', 'Bridal room'],
      imageUrl: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800',
      description: 'Elegant pillar-less ballroom suitable for weddings, gala dinners and award nights.',
    ),
    Hall(
      name: 'Seminar Hall A',
      location: 'Block B, Kampung Baru, Kuala Lumpur',
      capacity: 200,
      basePrice: 3200,
      amenities: ['Projector', 'PA system', 'Wi-Fi', 'Air-conditioning'],
      imageUrl: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
      description: 'Theatre-style hall ideal for talks, seminars and product launches.',
    ),
    Hall(
      name: 'Boardroom Teratai',
      location: 'Level 15, KL Sentral',
      capacity: 20,
      basePrice: 650,
      amenities: ['Smart TV', 'Video conferencing', 'Wi-Fi', 'Coffee corner'],
      imageUrl: 'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=800',
      description: 'Private boardroom for executive meetings and interviews.',
    ),
    Hall(
      name: 'Conference Room Melur',
      location: 'Level 3, Bangsar South',
      capacity: 60,
      basePrice: 1200,
      amenities: ['Projector', 'Whiteboard', 'Wi-Fi', 'Air-conditioning'],
      imageUrl: 'https://images.unsplash.com/photo-1431540015161-0bf868a2d407?w=800',
      description: 'Flexible room for workshops, trainings and team meetings.',
    ),
    Hall(
      name: 'Garden Pavilion',
      location: 'Taman Tasik, Shah Alam',
      capacity: 300,
      basePrice: 4800,
      amenities: ['Outdoor area', 'Parking', 'Fairy lights', 'Surau'],
      imageUrl: 'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?w=800',
      description: 'Semi-outdoor pavilion surrounded by greenery, perfect for receptions and family days.',
    ),
  ];

  static const List<Map<String, dynamic>> _sampleAddons = [
    {'name': 'Catering (buffet)', 'description': 'Buffet set for up to 100 guests', 'price': 2500},
    {'name': 'AV Equipment', 'description': 'Projector, screen, mics and speakers', 'price': 450},
    {'name': 'Decoration', 'description': 'Basic floral & stage decoration', 'price': 1200},
    {'name': 'Photography', 'description': '4-hour event photographer', 'price': 800},
    {'name': 'Live Streaming', 'description': 'Camera crew + streaming setup', 'price': 950},
    {'name': 'Extra Cleaning', 'description': 'Post-event deep cleaning', 'price': 200},
  ];
}
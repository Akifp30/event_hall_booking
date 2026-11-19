import 'package:cloud_firestore/cloud_firestore.dart';

/// Notis dalam app. Disimpan dalam collection `notifications`.
/// userId = uid pengguna, atau 'admins' untuk notis yang semua admin nampak.
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // booking | payment | cancel | reschedule
  final String bookingId;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.bookingId,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    final ts = m['createdAt'];
    return AppNotification(
      id: doc.id,
      userId: (m['userId'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      type: (m['type'] ?? 'info') as String,
      bookingId: (m['bookingId'] ?? '') as String,
      read: (m['read'] ?? false) as bool,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
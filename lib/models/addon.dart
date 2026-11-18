import 'package:cloud_firestore/cloud_firestore.dart';

/// An add-on service (catering, AV equipment, ...). Stored in the `addons` collection.
class Addon {
  final String id;
  final String name;
  final String description;
  final double price;

  const Addon({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
  });

  factory Addon.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Addon(
      id: doc.id,
      name: (m['name'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      price: (m['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

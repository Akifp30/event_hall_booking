import 'package:cloud_firestore/cloud_firestore.dart';

/// An event hall / conference room. Stored in the `halls` collection.
class Hall {
  final String id;
  final String name;
  final String location;
  final int capacity;
  final double basePrice;
  final List<String> amenities;
  final String imageUrl;
  final String description;
  final bool isActive; // hidden from users when false

  const Hall({
    this.id = '',
    required this.name,
    required this.location,
    required this.capacity,
    required this.basePrice,
    required this.amenities,
    required this.imageUrl,
    required this.description,
    this.isActive = true,
  });

  factory Hall.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Hall(
      id: doc.id,
      name: (m['name'] ?? '') as String,
      location: (m['location'] ?? '') as String,
      capacity: (m['capacity'] as num?)?.toInt() ?? 0,
      basePrice: (m['basePrice'] as num?)?.toDouble() ?? 0,
      amenities: List<String>.from(m['amenities'] ?? const []),
      imageUrl: (m['imageUrl'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      isActive: (m['isActive'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'location': location,
        'capacity': capacity,
        'basePrice': basePrice,
        'amenities': amenities,
        'imageUrl': imageUrl,
        'description': description,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

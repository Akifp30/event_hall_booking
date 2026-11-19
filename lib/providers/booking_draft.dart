import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../models/booking.dart';
import '../models/hall.dart';

/// Holds the booking the user is building across the 3-step flow
/// (date & time -> add-ons -> summary). Also used when editing a booking.
class BookingDraft extends ChangeNotifier {
  Hall? hall;
  DateTime? date;
  String? timeSlot;
  String? editingBookingId; // not null = editing an existing booking
  double editingAmountPaid = 0; // already paid on the booking being edited
  final List<Addon> _addons = [];

  List<Addon> get addons => List.unmodifiable(_addons);
  bool get isEditing => editingBookingId != null;

  double get addonsTotal => _addons.fold<double>(0, (sum, a) => sum + a.price);
  double get total => (hall?.basePrice ?? 0) + addonsTotal;

  /// What still needs to be paid after confirming.
  double get balanceAfterSave => total - editingAmountPaid;

  /// Start a new booking for [h].
  void start(Hall h) {
    hall = h;
    date = null;
    timeSlot = null;
    editingBookingId = null;
    editingAmountPaid = 0;
    _addons.clear();
    notifyListeners();
  }

  /// Re-enter the flow pre-filled with an existing booking.
  void startEdit(Booking b, Hall h) {
    hall = h;
    date = DateTime.tryParse(b.date);
    timeSlot = b.timeSlot;
    editingBookingId = b.id;
    editingAmountPaid = b.amountPaid;
    _addons
      ..clear()
      ..addAll(b.addons.map((a) => Addon(id: a.id, name: a.name, description: '', price: a.price)));
    notifyListeners();
  }

  void setDate(DateTime d) {
    if (date != null && DateUtils.isSameDay(date, d)) return;
    date = d;
    timeSlot = null; // availability changes with the date
    notifyListeners();
  }

  void setTimeSlot(String slot) {
    timeSlot = slot;
    notifyListeners();
  }

  bool isSelected(Addon a) => _addons.any((x) => x.id == a.id);

  void toggleAddon(Addon a) {
    if (isSelected(a)) {
      _addons.removeWhere((x) => x.id == a.id);
    } else {
      _addons.add(a);
    }
    notifyListeners();
  }

  void clear() {
    hall = null;
    date = null;
    timeSlot = null;
    editingBookingId = null;
    editingAmountPaid = 0;
    _addons.clear();
    notifyListeners();
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../providers/booking_draft.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Step 3: summary + confirmation. Saves (or updates) the booking.
class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _busy = false;

  Future<void> _confirm() async {
    final draft = context.read<BookingDraft>();
    final user = context.read<AuthService>().user;
    final db = context.read<FirestoreService>();
    final hall = draft.hall;
    if (hall == null || draft.date == null || draft.timeSlot == null || user == null) return;

    final ok = await confirmDialog(
      context,
      title: draft.isEditing ? 'Update this booking?' : 'Confirm booking?',
      message: '${hall.name}\n${prettyDate(dateKey(draft.date!))}\n${draft.timeSlot}\n\nTotal: ${rm(draft.total)}',
      confirmText: draft.isEditing ? 'Update' : 'Confirm',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final date = dateKey(draft.date!);

      // Double-check the slot is still free (someone may have booked it meanwhile).
      final taken = await db.bookedSlots(hall.id, date, excludeBookingId: draft.editingBookingId);
      if (taken.contains(draft.timeSlot)) {
        if (mounted) showSnack(context, 'Sorry, this slot was just booked. Please choose another time.');
        return;
      }

      final booking = Booking(
        id: draft.editingBookingId ?? '',
        userId: user.uid,
        userName: user.name,
        userEmail: user.email,
        hallId: hall.id,
        hallName: hall.name,
        date: date,
        timeSlot: draft.timeSlot!,
        addons: draft.addons.map((a) => BookedAddon(id: a.id, name: a.name, price: a.price)).toList(),
        hallPrice: hall.basePrice,
        totalPrice: draft.total,
      );

      final editing = draft.isEditing;
      if (editing) {
        await db.updateBooking(booking);
      } else {
        await db.createBooking(booking);
      }
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
          title: Text(editing ? 'Booking updated!' : 'Booking confirmed!'),
          content: Text(editing
              ? 'Your booking has been updated. New total: ${rm(booking.totalPrice)}.'
              : 'Your booking for ${hall.name} is confirmed.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('View my bookings')),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/my-bookings');
      draft.clear();
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to save booking: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final draft = context.watch<BookingDraft>();
    final hall = draft.hall;

    if (hall == null || draft.date == null || draft.timeSlot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.info_outline, message: 'Booking details are incomplete.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(draft.isEditing ? 'Edit booking' : 'New booking')),
      body: ListView(
        children: [
          const StepHeader(step: 3, title: 'Summary & confirmation'),
          Card(
            margin: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HallImage(url: hall.imageUrl, height: 140),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hall.name, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      IconText(icon: Icons.place_outlined, text: hall.location),
                      const Divider(height: 28),
                      _row(context, Icons.calendar_today_outlined, 'Date', prettyDate(dateKey(draft.date!))),
                      _row(context, Icons.schedule, 'Time', draft.timeSlot!),
                      const Divider(height: 28),
                      _price('Hall base price', hall.basePrice),
                      if (draft.addons.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('No add-ons selected', style: t.textTheme.bodySmall),
                        )
                      else
                        ...draft.addons.map((a) => _price(a.name, a.price)),
                      const Divider(height: 28),
                      Row(
                        children: [
                          Text('Total', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            rm(draft.total),
                            style: t.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: t.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Change add-ons'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: TotalBar(
        label: 'Final price',
        total: draft.total,
        buttonText: draft.isEditing ? 'Update booking' : 'Confirm booking',
        busy: _busy,
        onPressed: _confirm,
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: t.colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(width: 56, child: Text(label, style: t.textTheme.labelLarge)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _price(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label)), Text(rm(value))]),
      );
}

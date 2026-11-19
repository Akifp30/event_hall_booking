import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Admin: view and manage bookings from all users (search, filter, reschedule, cancel).
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  late final Stream<List<Booking>> _bookings = context.read<FirestoreService>().allBookings();
  String _query = '';
  String _filter = 'All';

  Future<void> _cancel(Booking b) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel booking?',
      message: 'Cancel ${b.userName}\'s booking for ${b.hallName} on ${prettyDate(b.date)}?',
      confirmText: 'Cancel booking',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<FirestoreService>().cancelBooking(b, by: 'admin');
      if (mounted) showSnack(context, 'Booking cancelled.');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e');
    }
  }

  Future<void> _reschedule(Booking b) async {
    final db = context.read<FirestoreService>();
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime date = DateTime.tryParse(b.date) ?? today;
    if (date.isBefore(today)) date = today;
    String slot = b.timeSlot;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool busy = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Reschedule booking'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.hallName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(prettyDate(dateKey(date))),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 365)),
                      initialDate: date,
                    );
                    if (picked != null) setD(() => date = picked);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: timeSlots.contains(slot) ? slot : timeSlots.first,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Time slot'),
                  items: timeSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setD(() => slot = v ?? slot),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setD(() {
                          busy = true;
                          error = null;
                        });
                        final key = dateKey(date);
                        final taken = await db.bookedSlots(b.hallId, key, excludeBookingId: b.id);
                        if (taken.contains(slot)) {
                          setD(() {
                            busy = false;
                            error = 'That slot is already booked.';
                          });
                          return;
                        }
                        await db.rescheduleBooking(b, date: key, timeSlot: slot);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (saved == true && mounted) showSnack(context, 'Booking rescheduled.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Bookings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search hall, customer or email', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final f in ['All', 'Upcoming', 'Completed', 'Cancelled'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Booking>>(
              stream: _bookings,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!.where((b) {
                  final matchQ = _query.isEmpty ||
                      b.hallName.toLowerCase().contains(_query) ||
                      b.userName.toLowerCase().contains(_query) ||
                      b.userEmail.toLowerCase().contains(_query);
                  final matchF = _filter == 'All' || b.statusLabel == _filter;
                  return matchQ && matchF;
                }).toList();
                if (list.isEmpty) return const EmptyState(icon: Icons.event_busy_outlined, message: 'No bookings found.');

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final b = list[i];
                    return BookingCard(
                      booking: b,
                      showUser: true,
                      actions: b.isUpcoming
                          ? [
                              TextButton.icon(
                                onPressed: () => _cancel(b),
                                icon: const Icon(Icons.close),
                                label: const Text('Cancel'),
                                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                              ),
                              const SizedBox(width: 4),
                              FilledButton.tonalIcon(
                                onPressed: () => _reschedule(b),
                                icon: const Icon(Icons.edit_calendar_outlined),
                                label: const Text('Reschedule'),
                              ),
                            ]
                          : const [],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

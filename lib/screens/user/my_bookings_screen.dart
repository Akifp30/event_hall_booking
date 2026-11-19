import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/booking.dart';
import '../../providers/booking_draft.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../notifications_screen.dart';

/// "My Bookings": view, edit (re-enter pre-filled flow), cancel and pay.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late final Stream<List<Booking>> _bookings = context
      .read<FirestoreService>()
      .userBookings(context.read<AuthService>().user?.uid ?? '');

  Future<void> _edit(Booking b) async {
    final db = context.read<FirestoreService>();
    final draft = context.read<BookingDraft>();
    final hall = await db.getHall(b.hallId);
    if (!mounted) return;
    if (hall == null) {
      showSnack(context, 'This hall is no longer available.');
      return;
    }
    draft.startEdit(b, hall);
    context.push('/book/date');
  }

  Future<void> _cancel(Booking b) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel booking?',
      message: 'Your booking for ${b.hallName} will be cancelled. This cannot be undone.'
          '${b.amountPaid > 0 ? '\n\nA refund of ${rm(b.amountPaid)} will be processed.' : ''}',
      confirmText: 'Cancel booking',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<FirestoreService>().cancelBooking(b);
      if (mounted) showSnack(context, 'Booking cancelled.');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to cancel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Bookings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          actions: const [NotificationBell()],
          bottom: const TabBar(tabs: [Tab(text: 'Upcoming'), Tab(text: 'History')]),
        ),
        body: StreamBuilder<List<Booking>>(
          stream: _bookings,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final all = snap.data!;
            final upcoming = all.where((b) => b.isUpcoming).toList()..sort((a, b) => a.date.compareTo(b.date));
            final history = all.where((b) => !b.isUpcoming).toList()..sort((a, b) => b.date.compareTo(a.date));

            return TabBarView(
              children: [
                _list(upcoming, 'No upcoming bookings.\nFind a hall and book your event!', editable: true),
                _list(history, 'No past or cancelled bookings.'),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.add),
          label: const Text('New booking'),
        ),
      ),
    );
  }

  Widget _list(List<Booking> items, String empty, {bool editable = false}) {
    if (items.isEmpty) return EmptyState(icon: Icons.event_busy_outlined, message: empty);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final b = items[i];
        return BookingCard(
          booking: b,
          actions: editable
              ? [
            TextButton.icon(
              onPressed: () => _cancel(b),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _edit(b),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            if (b.needsPayment)
              FilledButton.icon(
                onPressed: () => context.push('/pay/${b.id}'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Pay'),
              ),
          ]
              : const [],
        );
      },
    );
  }
}
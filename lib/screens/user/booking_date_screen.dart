import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/booking_draft.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Step 1: pick an event date (calendar) and a time slot.
/// Past dates and already-booked slots cannot be selected.
class BookingDateScreen extends StatefulWidget {
  const BookingDateScreen({super.key});

  @override
  State<BookingDateScreen> createState() => _BookingDateScreenState();
}

class _BookingDateScreenState extends State<BookingDateScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _focused;
  Future<Set<String>>? _bookedFuture;

  @override
  void initState() {
    super.initState();
    final draft = context.read<BookingDraft>();
    _focused = _today;
    final d = draft.date;
    if (d != null && !d.isBefore(_today)) {
      _focused = d;
      _loadSlots(d);
    }
  }

  void _loadSlots(DateTime day) {
    final draft = context.read<BookingDraft>();
    if (draft.hall == null) return;
    _bookedFuture = context.read<FirestoreService>().bookedSlots(
          draft.hall!.id,
          dateKey(day),
          excludeBookingId: draft.editingBookingId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final draft = context.watch<BookingDraft>();
    final hall = draft.hall;

    if (hall == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.info_outline, message: 'Please choose a hall first.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(draft.isEditing ? 'Edit booking' : 'New booking')),
      body: ListView(
        children: [
          StepHeader(step: 1, title: 'Choose date & time'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IconText(icon: Icons.meeting_room_outlined, text: hall.name),
          ),
          const SizedBox(height: 8),
          TableCalendar(
            firstDay: _today,
            lastDay: _today.add(const Duration(days: 365)),
            focusedDay: _focused,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
            selectedDayPredicate: (day) => draft.date != null && isSameDay(day, draft.date),
            enabledDayPredicate: (day) => !DateTime(day.year, day.month, day.day).isBefore(_today),
            onDaySelected: (selected, focused) {
              final picked = DateTime(selected.year, selected.month, selected.day);
              setState(() {
                _focused = focused;
                _loadSlots(picked);
              });
              draft.setDate(picked);
            },
            onPageChanged: (focused) => _focused = focused,
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(color: t.colorScheme.primary, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: t.colorScheme.primary.withAlpha(70), shape: BoxShape.circle),
              todayTextStyle: TextStyle(color: t.colorScheme.onSurface, fontWeight: FontWeight.bold),
              disabledTextStyle: TextStyle(color: t.colorScheme.outlineVariant),
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Time slot', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          if (draft.date == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select a date to see available time slots.'),
            )
          else
            FutureBuilder<Set<String>>(
              future: _bookedFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snap.error}'));
                }
                final booked = snap.data ?? const <String>{};
                return Column(
                  children: timeSlots.map((slot) {
                    final taken = booked.contains(slot);
                    final selected = draft.timeSlot == slot;
                    return Card(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      color: selected ? t.colorScheme.primaryContainer : null,
                      child: ListTile(
                        enabled: !taken,
                        leading: Icon(
                          taken
                              ? Icons.block
                              : selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                          color: taken ? t.colorScheme.error : t.colorScheme.primary,
                        ),
                        title: Text(slot),
                        subtitle: Text(taken ? 'Already booked' : 'Available'),
                        onTap: taken ? null : () => draft.setTimeSlot(slot),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: TotalBar(
        label: 'Hall base price',
        total: hall.basePrice,
        buttonText: 'Next: Add-ons',
        onPressed: (draft.date != null && draft.timeSlot != null) ? () => context.push('/book/addons') : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/common.dart';

/// Inbox id for the signed-in person (admins share one inbox).
String inboxFor(AuthService auth) => auth.isAdmin ? FirestoreService.adminsInbox : (auth.user?.uid ?? '');

/// Bell icon with unread badge, used in app bars.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final Stream<List<AppNotification>> _stream =
  context.read<FirestoreService>().notificationsStream(inboxFor(context.read<AuthService>()));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snap) {
        final unread = (snap.data ?? const <AppNotification>[]).where((n) => !n.read).length;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 9 ? '9+' : '$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}

/// List of notices (booking confirmed, payment received, cancelled, rescheduled...).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final FirestoreService _db = context.read<FirestoreService>();
  late final Stream<List<AppNotification>> _stream = _db.notificationsStream(inboxFor(context.read<AuthService>()));
  List<AppNotification> _latest = const [];

  IconData _icon(String type) => switch (type) {
    'payment' => Icons.payments_outlined,
    'cancel' => Icons.event_busy_outlined,
    'reschedule' => Icons.edit_calendar_outlined,
    _ => Icons.event_available_outlined,
  };

  String _time(DateTime? d) => d == null ? 'Just now' : DateFormat('d MMM, h:mm a').format(d);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await _db.markAllNotificationsRead(_latest);
              if (context.mounted) showSnack(context, 'All marked as read.');
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          _latest = snap.data!;
          if (_latest.isEmpty) {
            return const EmptyState(icon: Icons.notifications_none, message: 'No notifications yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _latest.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = _latest[i];
              return ListTile(
                tileColor: n.read ? null : t.colorScheme.primaryContainer.withAlpha(90),
                leading: CircleAvatar(
                  backgroundColor: t.colorScheme.secondaryContainer,
                  child: Icon(_icon(n.type), color: t.colorScheme.onSecondaryContainer),
                ),
                title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text('${n.body}\n${_time(n.createdAt)}'),
                isThreeLine: true,
                onTap: () {
                  if (!n.read) _db.markNotificationRead(n.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}
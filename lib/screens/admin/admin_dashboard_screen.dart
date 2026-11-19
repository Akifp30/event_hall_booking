import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common.dart';
import '../notifications_screen.dart';

/// Admin home: quick stats and links to management pages.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final FirestoreService _db = context.read<FirestoreService>();
  late final Stream<int> _hallCount = _db.hallsStream().map((l) => l.length);
  late final Stream<int> _upcomingCount = _db.allBookings().map((l) => l.where((b) => b.isUpcoming).length);
  late final Stream<int> _userCount = _db.usersStream().map((l) => l.length);
  bool _seeding = false;

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: 'Logout?', message: 'You will be signed out of the admin panel.', confirmText: 'Logout');
    if (!ok || !mounted) return;
    await context.read<AuthService>().logout();
    if (mounted) context.go('/');
  }

  Future<void> _seed() async {
    final ok = await confirmDialog(
      context,
      title: 'Load sample data?',
      message: 'Adds 5 demo halls and 6 add-on services (only if those lists are empty).',
      confirmText: 'Load',
    );
    if (!ok || !mounted) return;
    setState(() => _seeding = true);
    try {
      final msg = await _db.seedSampleData();
      if (mounted) showSnack(context, msg);
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final user = context.watch<AuthService>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const NotificationBell(),
          IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Welcome, ${user?.name ?? 'Admin'}', style: t.textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Halls', icon: Icons.meeting_room_outlined, stream: _hallCount),
              const SizedBox(width: 12),
              _Stat(label: 'Upcoming', icon: Icons.event_available_outlined, stream: _upcomingCount),
              const SizedBox(width: 12),
              _Stat(label: 'Users', icon: Icons.people_outline, stream: _userCount),
            ],
          ),
          const SizedBox(height: 24),
          Text('Manage', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.meeting_room_outlined,
            title: 'Halls',
            subtitle: 'Add, edit, hide or delete halls',
            onTap: () => context.push('/admin/halls'),
          ),
          _NavTile(
            icon: Icons.event_note_outlined,
            title: 'Bookings',
            subtitle: 'View, reschedule or cancel any booking',
            onTap: () => context.push('/admin/bookings'),
          ),
          _NavTile(
            icon: Icons.manage_accounts_outlined,
            title: 'User accounts',
            subtitle: 'Change roles, enable or disable accounts',
            onTap: () => context.push('/admin/users'),
          ),
          const SizedBox(height: 16),
          Card(
            color: t.colorScheme.tertiaryContainer,
            child: ListTile(
              leading: _seeding
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.dataset_outlined, color: t.colorScheme.onTertiaryContainer),
              title: const Text('Load sample data'),
              subtitle: const Text('Demo halls and add-on services'),
              onTap: _seeding ? null : _seed,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Stream<int> stream;
  const _Stat({required this.label, required this.icon, required this.stream});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Card(
        color: t.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: t.colorScheme.onPrimaryContainer),
              const SizedBox(height: 8),
              StreamBuilder<int>(
                stream: stream,
                builder: (context, snap) => Text(
                  snap.hasData ? '${snap.data}' : '-',
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: t.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Text(label, style: TextStyle(color: t.colorScheme.onPrimaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: t.colorScheme.secondaryContainer,
          child: Icon(icon, color: t.colorScheme.onSecondaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

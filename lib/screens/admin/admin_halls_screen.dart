import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/hall.dart';
import '../../services/firestore_service.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Admin: list of all halls (CRUD).
class AdminHallsScreen extends StatefulWidget {
  const AdminHallsScreen({super.key});

  @override
  State<AdminHallsScreen> createState() => _AdminHallsScreenState();
}

class _AdminHallsScreenState extends State<AdminHallsScreen> {
  late final Stream<List<Hall>> _halls = context.read<FirestoreService>().hallsStream();
  String _query = '';

  Future<void> _delete(Hall h) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${h.name}?',
      message: 'The hall will be removed permanently. Existing bookings keep their record.\n'
          'Tip: switch "Visible to users" off instead if you only want to hide it.',
      confirmText: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<FirestoreService>().deleteHall(h.id);
      if (mounted) showSnack(context, '${h.name} deleted.');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Halls')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/halls/form'),
        icon: const Icon(Icons.add),
        label: const Text('Add hall'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search halls', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Hall>>(
              stream: _halls,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final halls = snap.data!
                    .where((h) => _query.isEmpty || h.name.toLowerCase().contains(_query) || h.location.toLowerCase().contains(_query))
                    .toList();
                if (halls.isEmpty) {
                  return const EmptyState(icon: Icons.meeting_room_outlined, message: 'No halls yet. Tap "Add hall".');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: halls.length,
                  itemBuilder: (context, i) {
                    final h = halls[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                        leading: HallImage(url: h.imageUrl, height: 56, width: 56, radius: BorderRadius.circular(10)),
                        title: Row(
                          children: [
                            Flexible(child: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            if (!h.isActive) ...[
                              const SizedBox(width: 6),
                              Text('(hidden)', style: TextStyle(color: t.colorScheme.error, fontSize: 12)),
                            ],
                          ],
                        ),
                        subtitle: Text('${h.capacity} pax  •  ${rm(h.basePrice)}\n${h.location}'),
                        isThreeLine: true,
                        onTap: () => context.push('/admin/halls/form', extra: h),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') context.push('/admin/halls/form', extra: h);
                            if (v == 'delete') _delete(h);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
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
